#include <vector>
#include <syslog.h>
#include "trace_dump.h"

TraceDump::~TraceDump() {
	if (thread) {
		stop();
	}
}

void TraceDump::start() {
	if (!thread) {
		thread.reset(new std::thread(&TraceDump::thread_func, this));
	}
}

void TraceDump::stop() {
	if (thread) {
		begin_shutdown();
		thread->join();
		thread.reset(nullptr);
	}

	for (TraceMessageQueue::iterator i = message_queue.begin(); i != message_queue.end(); ++i) {
		process(i->get());
	}
}

void TraceDump::thread_func() {
	while (wait_and_process())
		;
}

bool TraceDump::wait_and_process() {
	using MessageBuffer = std::vector<TraceMessagePtr>;
	MessageBuffer incoming_messages;

	if (shutdown) {
		return false;
	}

	{
		std::unique_lock<std::mutex> guard(mutex);
		cond.wait(guard);
		
		if (shutdown) {
			return false;
		}

		for (TraceMessageQueue::iterator i = message_queue.begin(); i != message_queue.end(); ++i) {
			incoming_messages.push_back(std::move(*i));
		}
		message_queue.clear();
	}

	for (MessageBuffer::iterator i = incoming_messages.begin(); i != incoming_messages.end(); ++i) {
		process(i->get());
	}

	return true;
}

void TraceDump::process(TraceMessage* message) {
	printf("%s\n", message->get_buffer());
}

void FileTraceDump::process(TraceMessage* message) {
	fprintf(handle, "%s\n", message->get_buffer());
}

void SyslogTraceDump::process(TraceMessage* message) {
	syslog(LOG_DEBUG, "%s", message->get_buffer());
}
