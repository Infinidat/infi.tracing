#include <string>
#include "trace_message_ring_buffer.h"
#include "test_utils.h"

using namespace std;

bool test_alloc_dealloc() {
	{
		TraceMessageRingBuffer ring_buffer(1024, 1024);
		ASSERT_EQ(ring_buffer.get_capacity(), 1024);
		ASSERT_EQ(ring_buffer.get_trace_message_capacity(), 1024);
	}

	{
		TraceMessageRingBuffer ring_buffer(2048, 512);
		ASSERT_EQ(ring_buffer.get_capacity(), 2048);
		ASSERT_EQ(ring_buffer.get_trace_message_capacity(), 512);
	}
	return true;
}

bool test_empty_pop() {
	TraceMessageRingBuffer ring_buffer(2048, 512);
	TraceMessage m;
	ASSERT(! ring_buffer.pop(m));
	return true;
};

bool test_push_and_pop() {
	TraceMessageRingBuffer ring_buffer(2048, 512);
	TraceMessage* m = ring_buffer.reserve_push();
	ASSERT(m != NULL);
	ASSERT_EQ(m->write_offset(), 0);
	ASSERT_EQ(m->avail_size(), 512);
	m->printf("message1");
	m->set_timestamp();
	uint64_t ts = m->get_timestamp();
	ring_buffer.commit_push(m);

	TraceMessage result;
	ASSERT(ring_buffer.pop(result));

	ASSERT_EQ(result.get_timestamp(), ts);
	ASSERT_EQ(result.get_buffer(), string("message1"));
	return true;
};

MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_empty_pop);
	TEST(test_push_and_pop);
MAIN_TEST_CASE_END