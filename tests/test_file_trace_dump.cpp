#define BOOST_TEST_MODULE FileTraceDump
#include <stdio.h>
#include <boost/test/unit_test.hpp>
#include <string>
#include "trace_dump.h"

using namespace std;

BOOST_AUTO_TEST_SUITE(FileTraceDumpTests)

BOOST_AUTO_TEST_CASE(alloc_dealloc) {
		{
			TraceMessageRingBuffer ring_buffer(1024, 1024);
			FileTraceDump trace_dump(&ring_buffer, stdout, false);
		}
};

BOOST_AUTO_TEST_CASE(normal) {
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
};

BOOST_AUTO_TEST_SUITE_END()