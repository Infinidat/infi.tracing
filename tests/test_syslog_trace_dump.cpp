#include <syslog.h>
#include "trace_dump.h"
#include "test_utils.h"

using namespace std;

bool test_alloc_dealloc() {
	TraceMessageRingBuffer ring_buffer(1024, 1024);
	SyslogTCPSocket* socket = new SyslogTCPSocket("127.0.0.1", 6514);
	SyslogTraceDump trace_dump(&ring_buffer, "localhost", "test", "SyslogTraceDumpTests", LOG_LOCAL0, true,
							   socket);
	return true;
};

bool test_normal() {
	TraceMessageRingBuffer ring_buffer(1024, 1024);
	SyslogTCPSocket* socket = new SyslogTCPSocket("127.0.0.1", 6514);
	SyslogTraceDump trace_dump(&ring_buffer, "localhost", "test", "SyslogTraceDumpTests", LOG_LOCAL0, true,
							   socket);

	trace_dump.start();
	TraceMessage* msg = ring_buffer.reserve_push();
	msg->write("hello world!");
	msg->set_timestamp();
	ring_buffer.commit_push(msg);
	trace_dump.stop();
	return true;
};

MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_normal);
MAIN_TEST_CASE_END
