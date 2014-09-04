#include <sys/types.h>
#include <stdio.h>
#include <cstring>

#include "trace_dump.h"

#ifndef MINT_COMPILER_MSVC
#include <unistd.h>
#endif

using namespace std;

static void* _tracedump_thread_func_trampoline(void* ptr) {
    static_cast<TraceDump*>(ptr)->thread_func();
    return NULL;
}

TraceDump::~TraceDump() {
}

void TraceDump::start() {
	if (!thread_running) {
		// TODO assume success
	    mint_thread_create(&thread, _tracedump_thread_func_trampoline, this);
	    thread_running = true;
	}
}

void TraceDump::stop() {
	shutdown_thread();
	process_remaining();
}

void TraceDump::thread_func() {
	while (!shutdown) {
		if (!pop_and_process()) {
#ifdef MINT_COMPILER_MSVC
			Sleep(10);
#else
			struct timespec ts;
			ts.tv_sec = 0;
			ts.tv_nsec = 10 * 1000;
			nanosleep(&ts, NULL);
#endif
		}
	}
}

bool TraceDump::pop_and_process() {
	unsigned long overflow = ring_buffer->get_and_reset_overflow_counter();
	if (overflow > 0) {
		process_overflow(overflow);
	}

	if (ring_buffer->pop(message_buffer)) {
		process();
		return true;
	}
	return false;
}

void TraceDump::process() {
	printf("%s\n", message_buffer.get_buffer());
}

void TraceDump::process_overflow(unsigned long messages_lost) {
	message_buffer.recycle();
	message_buffer.set_timestamp();
	message_buffer.set_severity(4);  // LOG_WARN in syslog - other writers may override this method.
#ifdef MINT_COMPILER_MSVC
	long pid = static_cast<long>(GetCurrentProcessId());
#else
	long pid = getpid();
#endif
	message_buffer.printf("pid %ld lost %ld messages due to overflow", pid, messages_lost);
	process();
}

void TraceDump::shutdown_thread() {
	if (thread_running) {
		shutdown = true;
		mint_thread_join(thread, NULL);
		thread_running = false;
	}
}

void TraceDump::process_remaining() {
	while (pop_and_process())
		;
}

FileTraceDump::~FileTraceDump() {
	stop();
}

void FileTraceDump::process() {
#ifdef MINT_COMPILER_MSVC
	// TODO convert timestamp to iso_time on windows
	fprintf(handle, "%s\n", message_buffer.get_buffer());
#else
	uint64_t ts = message_buffer.get_timestamp();
	time_t t = static_cast<time_t>(ts / 1000);
	struct tm tm;

#ifdef MINT_COMPILER_MSVC
	gmtime_s(&tm, &t);
#else
	gmtime_r(&t, &tm);
#endif

	char iso_time[128];
	int l = sprintf(iso_time, "%04d-%02d-%02dT%02d:%02d:%02d", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
				    tm.tm_hour, tm.tm_min, tm.tm_sec);
	int frac = static_cast<int>(ts % 1000);
	if (frac != 0) {
		l += sprintf(&iso_time[l], ".%06d", frac); // rsyslog doesn't handle ',' as the frac sep well
	}

	fprintf(handle, "%sZ\t%s\n", iso_time, message_buffer.get_buffer());
#endif
}

void FileTraceDump::flush() {
	fflush(handle);
}

void FileTraceDump::stop() {
	shutdown_thread();
	if (close_handle && handle != NULL) {
		process_remaining();
		fclose(handle);
		handle = NULL;
	}
}

#ifndef MINT_COMPILER_MSVC
#include <syslog.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <arpa/inet.h>

SyslogSocket::SyslogSocket() : fd(-1) {
}

SyslogSocket::~SyslogSocket() {
	close();
}

void SyslogSocket::close() {
	if (fd != -1) {
		::close(fd);
		fd = -1;
	}
}

SyslogUNIXSocket::SyslogUNIXSocket(const char* _address) : SyslogSocket(), address(_address) {
}

bool SyslogUNIXSocket::try_connect() {
	if (fd != -1) {
		return true;
	}
	if (!try_connect_to_type(SOCK_DGRAM)) {
		return try_connect_to_type(SOCK_STREAM);
	}
	return true;
}

bool SyslogUNIXSocket::send(const char* buffer, ssize_t size) {
	if (::send(fd, buffer, size, 0) != size) {
		close();
		return false;
	}
	return true;
}

bool SyslogUNIXSocket::try_connect_to_type(int type) {
	fd = socket(AF_UNIX, type, 0);
	if (fd == -1) {
		return false;
	}

	sockaddr_un sockaddr;
	sockaddr.sun_family = AF_UNIX;
	std::strncpy(sockaddr.sun_path, address.c_str(), sizeof(sockaddr.sun_path));
	if (::connect(fd, reinterpret_cast<struct sockaddr*>(&sockaddr), sizeof(sockaddr)) != 0) {
		close();
		return false;
	}

	return true;
}

SyslogTCPSocket::SyslogTCPSocket(const char* _address, int _port): SyslogSocket() {
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = inet_addr(_address);
	address.sin_port = htons(_port);
}

bool SyslogTCPSocket::try_connect() {
	if (fd != -1) {
		return true;
	}
	fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd == -1) {
		return false;
	}
	if (::connect(fd, reinterpret_cast<struct sockaddr*>(&address), sizeof(address)) != 0) {
		close();
		return false;
	}
	return true;
}

bool SyslogTCPSocket::send(const char* buffer, ssize_t size) {
	// http://tools.ietf.org/html/rfc6587#section-3.4.1
	// MSG-LEN SP SYSLOG-MSG
	char size_prefix[64];
	int prefix_len = snprintf(size_prefix, sizeof(size_prefix), "%ld ", size);
	if (prefix_len < 0 || prefix_len == sizeof(size_prefix)) {
		// Bad message (too big??) - nothing to do here.
		return false;
	}

	if (::send(fd, size_prefix, prefix_len, 0) == prefix_len) {
		if (::send(fd, buffer, size, 0) == size) {
			return true;
		}
	}
	close();
	return false;
}

SyslogTraceDump::SyslogTraceDump(TraceMessageRingBuffer* _ring_buffer, const char* _host_name,
								 const char* _application_name, const char* _process_id, int _facility, bool _rfc5424,
								 SyslogSocket* _socket):
	TraceDump(_ring_buffer),
	host_name(),
	application_name(),
	process_id(),
	rfc5424(_rfc5424),
	facility(_facility),
	socket(_socket),
	syslog_buffer_size(_ring_buffer->get_trace_message_capacity() + 8192),
	syslog_buffer(new char[syslog_buffer_size]) {
	host_name = (_host_name == NULL || _host_name[0] == '\0') ? "-" : _host_name;
	application_name = (_application_name == NULL || _application_name[0] == '\0') ? "-" : _application_name;
	process_id = (_process_id == NULL || _process_id[0] == '\0') ? "-" : _process_id;
}

SyslogTraceDump::~SyslogTraceDump() {
	stop();
	delete[] syslog_buffer;
}

void SyslogTraceDump::stop() {
	shutdown_thread();
	if (socket != NULL) {
		process_remaining();
		socket->close();
		delete socket;
		socket = NULL;
	}
}

void SyslogTraceDump::process() {
	ssize_t size = format_message();
    if (size > 0) {
    	// Try twice to send the message: first time may fail because the connection got reset.
    	for (int i = 0 ; i < 2; ++i) {
	    	if (socket->try_connect()) {
		        if (socket->send(syslog_buffer, size)) {
		        	break;
		        }
		    }
		}
    }
}

int SyslogTraceDump::format_message() {
	int severity = message_buffer.get_severity();
	if (severity == SEVERITY_NOTSET) {
		severity = LOG_DEBUG;
	}
	int priority = (facility << 3) + severity;

	int result;
	if (rfc5424) {
		uint64_t ts = message_buffer.get_timestamp();
		time_t t = static_cast<time_t>(ts / 1000);
		struct tm tm;
		gmtime_r(&t, &tm);

		char iso_time[128];
		int l = sprintf(iso_time, "%04d-%02d-%02dT%02d:%02d:%02d", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
					    tm.tm_hour, tm.tm_min, tm.tm_sec);
		int frac = static_cast<int>(ts % 1000);
		if (frac != 0) {
			l += sprintf(&iso_time[l], ".%06d", frac); // rsyslog doesn't handle ',' as the frac sep well
		}

		// RFC 5424 (see https://tools.ietf.org/html/rfc5424):
      	// SYSLOG-MSG      = HEADER SP STRUCTURED-DATA [SP MSG]
      	// HEADER          = PRI VERSION SP TIMESTAMP SP HOSTNAME SP APP-NAME SP PROCID SP MSGID
      	//
      	// Where:
      	// - PRI is <..>,
      	// - VERSION is 1
      	// - SP is ' ' (space)
      	// - TIMESTAMP is ISO date (Z is important at the end)
      	// - STURCTURED-DATA we keep as '-' (NILVALUE)
      	// - MSGID we keep as '-' (NILVALUE)
      	// - MSG is the actual message
		result = snprintf(syslog_buffer, syslog_buffer_size, "<%d>1 %sZ %s %s %s - - %s",
						  priority, iso_time, host_name.c_str(), application_name.c_str(), process_id.c_str(),
						  message_buffer.get_buffer());
	} else {
		result = snprintf(syslog_buffer, syslog_buffer_size, "<%d>[%s]: %s", priority,
						  application_name.c_str(), message_buffer.get_buffer());
	}

	if (result == syslog_buffer_size) {
		// truncated - no need to add +1 for NULL.
		return result;
	} else if (result > 0) {
		return result + 1;
	}

	return -1;
}
#endif // MINT_COMPILER_MSVC
