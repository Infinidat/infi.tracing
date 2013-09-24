#ifndef __trace_dump_h__
#define __trace_dump_h__

#include <string>
#include <boost/thread.hpp>
#include <boost/smart_ptr.hpp>

#include "trace_message.h"
#include "trace_message_ring_buffer.h"

class TraceDump {
public:
	TraceDump(TraceMessageRingBuffer* _ring_buffer) : message_buffer(), shutdown(false), ring_buffer(_ring_buffer) {}
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
	boost::scoped_ptr<boost::thread> thread;
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

class SyslogSocket;

class SyslogTraceDump: public TraceDump {
public:
	~SyslogTraceDump();

	void stop();

	static SyslogTraceDump* create_with_unix_socket(TraceMessageRingBuffer* ring_buffer, const char* _host_name,
												    const char* application_name, const char* _process_id, int facility,
												    bool rfc5424, const char* address);

	static SyslogTraceDump* create_with_tcp_socket(TraceMessageRingBuffer* ring_buffer, const char* host_name,
												   const char* application_name, const char* process_id, int facility,
												   bool rfc5424, const char* address, int port);

protected:
	SyslogTraceDump(TraceMessageRingBuffer* _ring_buffer, const char* _host_name, const char* _application_name,
					const char* _process_id, int _facility, bool _rfc5424, SyslogSocket* _socket);

	std::string host_name;
	std::string application_name;
	std::string process_id;
	bool rfc5424;
	int facility;
	boost::scoped_ptr<SyslogSocket> socket;
	char syslog_buffer[32768];

	void process();

	int format_message();
};

#endif
