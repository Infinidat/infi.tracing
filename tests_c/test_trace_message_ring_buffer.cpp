#include <string>
#include "mintomic/platform_detect.h"
#ifdef MINT_COMPILER_GCC
#include <unistd.h>
#else
#define NOMINMAX
#include <windows.h>
#endif
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
}

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
}

bool test_lots_of_pushes() {
	TraceMessageRingBuffer ring_buffer(2048, 512);
	for (int i = 0; i < 4096; ++i) {
		TraceMessage* m = ring_buffer.reserve_push();
		ASSERT(m != NULL);
		m->printf("message1");
		m->set_timestamp();
		ring_buffer.commit_push(m);
	}
	ASSERT_EQ(ring_buffer.get_overflow_counter(), 2048);
	return true;
}

#define SINGLE_PRODUCER_SINGLE_CONSUMER_CONCURRENCY_ITERS 65536
#define SINGLE_PRODUCER_SINGLE_CONSUMER_BUFFER_SIZE 4096

void* _validating_consumer(void* arg) {
	TraceMessageRingBuffer* buffer = reinterpret_cast<TraceMessageRingBuffer*>(arg);
	TraceMessage m;
	for (int i = 0; i < SINGLE_PRODUCER_SINGLE_CONSUMER_CONCURRENCY_ITERS; ++i) {
		while (!buffer->pop(m))
			;
		char buf[512];
		sprintf(buf, "%d", i);
		if (m.get_buffer() != string(buf)) {
			fprintf(stderr, "failed to compare message %d: %s != %s\n", i, m.get_buffer(), buf);
			return NULL;
		}
		if (buffer->get_overflow_counter() != 0) {
			fprintf(stderr, "overflow counter > 0 (%lu) while processing message %d\n",
					buffer->get_overflow_counter(), i);
			return NULL;
		}
	}
	return NULL;
}

bool test_concurrency_single_producer_single_consumer() {
	TraceMessageRingBuffer ring_buffer(SINGLE_PRODUCER_SINGLE_CONSUMER_BUFFER_SIZE, 512);
	mint_thread_t thread;
	if (mint_thread_create(&thread, _validating_consumer, &ring_buffer) != 0) {
		FAIL("mint_thread_create failed");
	}

	for (int i = 0; i < SINGLE_PRODUCER_SINGLE_CONSUMER_CONCURRENCY_ITERS; i++) {
		TraceMessage* m = ring_buffer.reserve_push();
		m->printf("%d", i);
		m->set_timestamp();
		ring_buffer.commit_push(m);
#ifdef MINT_COMPILER_GCC
		usleep(1);
#else
		Sleep(1);
#endif
	}

	void* rv;
	if (mint_thread_join(thread, &rv) != 0) {
		FAIL("mint_thread_join failed");
	}

	ASSERT_EQ(ring_buffer.get_overflow_counter(), 0);

	return true;
}

#define MULTI_PRODUCER_CONCURRENCY_ITERS 10000
#define MULTI_PRODUCER_CONCURRENCY_PRODUCERS 4
#define MULTI_PRODUCER_CONCURRENCY_BUFFER_SIZE 16384

void* _non_validating_consumer(void* arg) {
	TraceMessageRingBuffer* buffer = reinterpret_cast<TraceMessageRingBuffer*>(arg);
	TraceMessage m;
	for (int i = 0; i < MULTI_PRODUCER_CONCURRENCY_PRODUCERS * MULTI_PRODUCER_CONCURRENCY_ITERS; ++i) {
		while (!buffer->pop(m))
			;
		if (buffer->get_overflow_counter() != 0) {
			fprintf(stderr, "overflow counter > 0 (%lu) while processing message %d\n",
					buffer->get_overflow_counter(), i);
			return NULL;
		}
	}
	return NULL;
}

void* _producer(void* arg) {
	TraceMessageRingBuffer* ring_buffer = reinterpret_cast<TraceMessageRingBuffer*>(arg);
	for (int i = 0; i < MULTI_PRODUCER_CONCURRENCY_ITERS; ++i) {
		TraceMessage* m = ring_buffer->reserve_push();
		m->printf("%d", i);
		m->set_timestamp();
		ring_buffer->commit_push(m);
#ifdef MINT_COMPILER_GCC
		usleep(1);
#else
		Sleep(1);
#endif
	}
	return NULL;
}

bool test_concurrency_multi_producer_single_consumer() {
	TraceMessageRingBuffer ring_buffer(MULTI_PRODUCER_CONCURRENCY_BUFFER_SIZE, 512);
	mint_thread_t consumer_thread;
	if (mint_thread_create(&consumer_thread, _non_validating_consumer, &ring_buffer) != 0) {
		FAIL("mint_thread_create failed for _non_validating_consumer");
	}

	mint_thread_t producer_threads[MULTI_PRODUCER_CONCURRENCY_PRODUCERS];
	for (int i = 0; i < MULTI_PRODUCER_CONCURRENCY_PRODUCERS; ++i) {
		if (mint_thread_create(&producer_threads[i], _producer, &ring_buffer) != 0) {
			FAIL("mint_thread_create failed for _producer");
		}
	}

	void* rv;
	for (int i = 0; i < MULTI_PRODUCER_CONCURRENCY_PRODUCERS; ++i) {
		if (mint_thread_join(producer_threads[i], &rv) != 0) {
			FAIL("mint_thread_join failed for _producer");
		}
	}
	if (mint_thread_join(consumer_thread, &rv) != 0) {
		FAIL("mint_thread_join failed for _consumer");
	}

	ASSERT_EQ(ring_buffer.get_overflow_counter(), 0);
	return true;
}

MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_empty_pop);
	TEST(test_push_and_pop);
	TEST(test_lots_of_pushes);
	TEST(test_concurrency_single_producer_single_consumer);
	TEST(test_concurrency_multi_producer_single_consumer);
MAIN_TEST_CASE_END