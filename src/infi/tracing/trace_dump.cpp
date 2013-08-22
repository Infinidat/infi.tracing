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
		shutdown = true;
		thread->join();
		thread.reset(nullptr);
	}

	TraceMessage* ptr = ring_buffer.reserve_pop(0);
	while (ptr != 0) {
		process(ptr);
		ring_buffer.commit_pop();
		ptr = ring_buffer.reserve_pop(0);
	}
}

void TraceDump::thread_func() {
	while (wait_and_process())
		;
}

bool TraceDump::wait_and_process() {
	if (shutdown) {
		return false;
	}

	TraceMessage* message = ring_buffer.reserve_pop(250);
	if (message == 0) {
		return !shutdown;
	}

	process(message);

	ring_buffer.commit_pop();

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
