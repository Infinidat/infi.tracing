#include <boost/chrono.hpp>
#include <stdio.h>
#include <syslog.h>
#include "trace_dump.h"

TraceDump::~TraceDump() {
	if (thread) {
		stop();
	}
}

void TraceDump::start() {
	if (!thread) {
		thread.reset(new boost::thread(&TraceDump::thread_func, this));
	}
}

void TraceDump::stop() {
	if (thread) {
		shutdown = true;
		thread->join();
		thread.reset();
	}

	while (pop_and_process())
		;
}

void TraceDump::thread_func() {
	while (!shutdown) {
		if (!pop_and_process()) {
			boost::this_thread::sleep_for(boost::chrono::milliseconds(10));
		}
	}
}

bool TraceDump::pop_and_process() {
	char buffer[TRACE_MESSAGE_MAX_SIZE + 1];
	if (ring_buffer.pop(buffer, sizeof(buffer))) {
		process(buffer);
		return true;
	}
	return false;
}

void TraceDump::process(const char* message) {
	printf("%s\n", message);
}

void FileTraceDump::process(const char* message) {
	fprintf(handle, "%s\n", message);
}

void FileTraceDump::flush() {
	fflush(handle);
}

void SyslogTraceDump::process(const char* message) {
	syslog(LOG_DEBUG, "%s", message);
}
