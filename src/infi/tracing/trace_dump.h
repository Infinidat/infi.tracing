#ifndef __trace_dump_h__
#define __trace_dump_h__

#define NOMINMAX  // For windows.h not to define min() and max()
#include <string>
#include <mintsystem/thread.h>

#include "trace_message.h"
#include "trace_message_ring_buffer.h"

static void* _tracedump_thread_func_trampoline(void* ptr);

class TraceDump {
public:
	TraceDump(TraceMessageRingBuffer* _ring_buffer):
		message_buffer(_ring_buffer->get_trace_message_capacity()),
		shutdown(false),
		ring_buffer(_ring_buffer),
		thread(),
		thread_running(false) {}

	virtual ~TraceDump();

	virtual void start();

	virtual void stop();

protected:
	TraceMessage message_buffer;

	void thread_func();
	bool pop_and_process();
	virtual void process();
	virtual void flush() {}

	virtual void process_overflow(unsigned long messages_lost);

	void shutdown_thread();

	void process_remaining();

private:
	bool shutdown;
	TraceMessageRingBuffer* ring_buffer;
	mint_thread_t thread;
	bool thread_running;

	friend void* _tracedump_thread_func_trampoline(void* ptr);
};


class FileTraceDump: public TraceDump {
public:
	FileTraceDump(TraceMessageRingBuffer* _ring_buffer, FILE* f, bool _close_handle):
		TraceDump(_ring_buffer),
		handle(f),
		close_handle(_close_handle) {}

	~FileTraceDump();

	void stop();

protected:
	void process();
	void flush();

private:
	FILE* handle;
	bool close_handle;
};


#ifndef MINT_COMPILER_MSVC
#include <netinet/in.h>


class SyslogSocket {
public:
	SyslogSocket();

	virtual ~SyslogSocket();

	virtual bool try_connect() = 0;

	virtual bool send(const char* buffer, ssize_t size) = 0;

	virtual void close();

protected:
	int fd;
};


class SyslogUNIXSocket : public SyslogSocket {
public:
	SyslogUNIXSocket(const char* _address);

	bool try_connect();

	bool send(const char* buffer, ssize_t size);

private:
	bool try_connect_to_type(int type);

	std::string address;
};


class SyslogTCPSocket : public SyslogSocket {
public:
	SyslogTCPSocket(const char* _address, int _port);

	bool try_connect();

	bool send(const char* buffer, ssize_t size);

private:
	struct sockaddr_in address;
};


class SyslogTraceDump: public TraceDump {
public:
	SyslogTraceDump(TraceMessageRingBuffer* _ring_buffer, const char* _host_name, const char* _application_name,
					const char* _process_id, int _facility, bool _rfc5424, SyslogSocket* _socket);
	~SyslogTraceDump();

	void stop();

protected:
	std::string host_name;
	std::string application_name;
	std::string process_id;
	bool rfc5424;
	int facility;
	SyslogSocket* socket;
	int syslog_buffer_size;
	char* syslog_buffer;

	void process();

	int format_message();
};
#endif // MINT_COMPILER_MSVC

#endif
