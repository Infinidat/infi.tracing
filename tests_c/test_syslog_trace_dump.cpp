#include <syslog.h>
#include <unistd.h>
#include "trace_dump.h"
#include "test_utils.h"

using namespace std;

bool test_alloc_dealloc() {
	TraceMessageRingBuffer ring_buffer(1024, 1024);
	SyslogTCPSocket* socket = new SyslogTCPSocket("127.0.0.1", 6514);
	SyslogTraceDump trace_dump(&ring_buffer, "localhost", "test", "SyslogTraceDumpTests", LOG_LOCAL0, true,
							   socket);
	return true;
}

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
}

#define CONCURRENCY_PRODUCERS 	2
#define CONCURRENCY_PRODUCER_SLEEP_MS 5
#define CONCURRENCY_ITERS		100000
#define CONCURRENCY_BUFFER_SIZE	16384

void* _producer(void* arg) {
	TraceMessageRingBuffer* ring_buffer = reinterpret_cast<TraceMessageRingBuffer*>(arg);
	for (int i = 0; i < CONCURRENCY_ITERS; ++i) {
		TraceMessage* m = ring_buffer->reserve_push();
		m->printf("%d", i);
		m->set_timestamp();
		ring_buffer->commit_push(m);
		usleep(CONCURRENCY_PRODUCER_SLEEP_MS);
	}
	return NULL;
}

bool test_concurrency() {
	TraceMessageRingBuffer ring_buffer(CONCURRENCY_BUFFER_SIZE, 512);

	SyslogTCPSocket* socket = new SyslogTCPSocket("127.0.0.1", 514);
	SyslogTraceDump trace_dump(&ring_buffer, "localhost", "test", "SyslogTraceDumpTests", LOG_LOCAL0, true,
							   socket);
	trace_dump.start();

	mint_thread_t producer_threads[CONCURRENCY_PRODUCERS];
	for (int i = 0; i < CONCURRENCY_PRODUCERS; ++i) {
		if (mint_thread_create(&producer_threads[i], _producer, &ring_buffer) != 0) {
			FAIL("mint_thread_create failed for _producer");
		}
	}

	void* rv;
	for (int i = 0; i < CONCURRENCY_PRODUCERS; ++i) {
		if (mint_thread_join(producer_threads[i], &rv) != 0) {
			FAIL("mint_thread_join failed for _producer");
		}
	}

	trace_dump.stop();
	if (ring_buffer.get_overflow_counter() != 0) {
		fprintf(stderr, "get_overflow_counter() > 0 (%lu) for test_concurrency\n", ring_buffer.get_overflow_counter());
		ASSERT(false);
	}
}


MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_normal);
	TEST(test_concurrency);
MAIN_TEST_CASE_END
