#include <string>
#include "trace_message_ring_buffer.h"
#include "test_utils.h"
#include "mintsystem/thread.h"

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
	ASSERT_EQ(ring_buffer.get_overflow_counter(), 0);

	TraceMessage* m = ring_buffer.reserve_push();
	ASSERT_EQ(ring_buffer.get_overflow_counter(), 0);
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
	ASSERT_EQ(ring_buffer.get_overflow_counter(), 0);
	return true;
};

void* _consumer(void* arg) {
	TraceMessageRingBuffer* buffer = reinterpret_cast<TraceMessageRingBuffer*>(arg);
	TraceMessage m;
	for (int i = 0; i < 100; ++i) {
		while (!buffer->pop(m))
			;
		char buf[512];
		sprintf(buf, "%d", i);
		if (m.get_buffer() != string(buf)) {
			fprintf(stderr, "failed to compare message %d: %s != %s\n", i, m.get_buffer(), buf);
			return NULL;
		}
		if (buffer->get_overflow_counter() != 0) {
			fprintf(stderr, "overflow counter > 0 while processing message %d\n", i);
			return NULL;
		}
	}
	return NULL;
}

bool test_concurrency() {
	TraceMessageRingBuffer ring_buffer(2048, 512);
	mint_thread_t thread;
	if (mint_thread_create(&thread, _consumer, &ring_buffer) != 0) {
		FAIL("mint_thread_create failed");
	}

	for (int i = 0; i < 100; i++) {
		TraceMessage* m = ring_buffer.reserve_push();
		m->printf("%d", i);
		m->set_timestamp();
		ring_buffer.commit_push(m);
	}

	void* rv;
	if (mint_thread_join(thread, &rv) != 0) {
		FAIL("mint_thread_join failed");
	}

	ASSERT_EQ(ring_buffer.get_overflow_counter(), 0);

	return true;
}

MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_empty_pop);
	TEST(test_push_and_pop);
	TEST(test_concurrency);
MAIN_TEST_CASE_END