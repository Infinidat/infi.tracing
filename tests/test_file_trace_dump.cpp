#include <stdio.h>
#include <string>
#include "trace_dump.h"
#include "test_utils.h"

using namespace std;

bool test_alloc_dealloc() {
	TraceMessageRingBuffer ring_buffer(1024, 1024);
	FileTraceDump trace_dump(&ring_buffer, stdout, false);
	return true;
}

bool test_normal() {
	{
		TraceMessageRingBuffer ring_buffer(1024, 1024);
		FileTraceDump trace_dump(&ring_buffer, stdout, false);

		trace_dump.start();
		TraceMessage* msg = ring_buffer.reserve_push();
		msg->write("hello world!");
		msg->set_timestamp();
		ring_buffer.commit_push(msg);
		trace_dump.stop();
	}


	{
		FILE* f = fopen("/tmp/test.log", "wb");
		TraceMessageRingBuffer ring_buffer(1024, 1024);
		FileTraceDump trace_dump(&ring_buffer, f, true);

		trace_dump.start();
		TraceMessage* msg = ring_buffer.reserve_push();
		msg->write("hello world!");
		msg->set_timestamp();
		ring_buffer.commit_push(msg);
		trace_dump.stop();
	}
	return true;
}

MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_normal);
MAIN_TEST_CASE_END
