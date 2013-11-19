#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <syslog.h>
#include <stdio.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <cstring>
#include <boost/chrono.hpp>
#include <boost/lexical_cast.hpp>

#include "trace_dump.h"

using namespace std;
using namespace boost::posix_time;

TraceDump::~TraceDump() {
}

void TraceDump::start() {
	if (!thread) {
		thread.reset(new boost::thread(&TraceDump::thread_func, this));
	}
}

void TraceDump::stop() {
	shutdown_thread();
	process_remaining();
}

void TraceDump::thread_func() {
	while (!shutdown) {
		if (!pop_and_process()) {
			boost::this_thread::sleep_for(boost::chrono::milliseconds(10));
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
	message_buffer.printf("pid %ld lost %ld messages due to overflow", getpid(), messages_lost);
	process();
}

void TraceDump::shutdown_thread() {
	if (thread) {
		shutdown = true;
		thread->join();
		thread.reset();
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
	fprintf(handle, "%s\n", message_buffer.get_buffer());
}

void FileTraceDump::flush() {
	fflush(handle);
}

void FileTraceDump::stop() {
	shutdown_thread();
	process_remaining();
	if (close_handle && handle != NULL) {
		fclose(handle);
		handle = NULL;
	}
}

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
}

void SyslogTraceDump::stop() {
	shutdown_thread();
	process_remaining();
	if (socket) {
		socket->close();
	}
}

void SyslogTraceDump::process() {
	ssize_t size = format_message();
    if (size > 0) {
    	// Try twice to send the message: first time may fail because the connection got reset.
    	for (int i = 0 ; i < 2; ++i) {
	    	if (socket->try_connect()) {
		        if (socket->send(syslog_buffer.get(), size)) {
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
		string iso_time = to_iso_extended_string(message_buffer.get_timestamp());
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
		result = snprintf(syslog_buffer.get(), syslog_buffer_size, "<%d>1 %sZ %s %s %s - - %s",
						  priority, iso_time.c_str(), host_name.c_str(), application_name.c_str(), process_id.c_str(),
						  message_buffer.get_buffer());
	} else {
		result = snprintf(syslog_buffer.get(), syslog_buffer_size, "<%d>[%s]: %s", priority,
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
