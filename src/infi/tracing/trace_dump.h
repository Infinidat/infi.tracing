#ifndef __trace_dump_h__
#define __trace_dump_h__

#include <thread>
#include <deque>
#include <mutex>
#include <condition_variable>

#include "trace_message.h"

class TraceDump {
public:
	TraceDump() : shutdown(false) {}
	virtual ~TraceDump();

	void start();

	void stop();

	void push(TraceMessagePtr&& ptr) {
		{
			std::lock_guard<std::mutex> guard(mutex);
			message_queue.push_back(std::move(ptr));
		}
		cond.notify_one();
	}

	void begin_shutdown() {
		shutdown = true;
		cond.notify_one();
	}

protected:
	void thread_func();
	bool wait_and_process();
	virtual void process(TraceMessage* message) = 0;

private:
	typedef std::deque<TraceMessagePtr> TraceMessageQueue;

	bool shutdown;
	std::mutex mutex;
	std::condition_variable cond;
	TraceMessageQueue message_queue;
	std::unique_ptr<std::thread> thread;
};

class FileTraceDump: public TraceDump {
public:
	FileTraceDump(FILE* f) : handle(f) {}

protected:
	void process(TraceMessage* message);

private:
	FILE* handle;
};

class SyslogTraceDump: public TraceDump {
protected:
	void process(TraceMessage* message);
};

#endif