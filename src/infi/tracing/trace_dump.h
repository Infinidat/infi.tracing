#ifndef __trace_dump_h__
#define __trace_dump_h__

#include <thread>

#include "trace_message.h"
#include "trace_message_ring_buffer.h"

class TraceDump {
public:
	TraceDump(TraceMessageRingBuffer& _ring_buffer) : shutdown(false), ring_buffer(_ring_buffer) {}
	virtual ~TraceDump();

	void start();

	void stop();

protected:
	void thread_func();
	bool wait_and_process();
	virtual void process(TraceMessage* message) = 0;

private:
	bool shutdown;
	TraceMessageRingBuffer& ring_buffer;
	std::unique_ptr<std::thread> thread;
};

class FileTraceDump: public TraceDump {
public:
	FileTraceDump(TraceMessageRingBuffer& _ring_buffer, FILE* f) : TraceDump(_ring_buffer), handle(f) {}

protected:
	void process(TraceMessage* message);

private:
	FILE* handle;
};

class SyslogTraceDump: public TraceDump {
public:
	SyslogTraceDump(TraceMessageRingBuffer& _ring_buffer) : TraceDump(_ring_buffer) {}

protected:
	void process(TraceMessage* message);
};

#endif