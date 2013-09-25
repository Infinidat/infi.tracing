#define BOOST_TEST_MODULE SyslogTraceDump
#include <syslog.h>
#include <boost/test/unit_test.hpp>
#include <string>
#include "trace_dump.h"

using namespace std;

BOOST_AUTO_TEST_SUITE(SyslogTraceDumpTests)

BOOST_AUTO_TEST_CASE(alloc_dealloc) {
		{
			TraceMessageRingBuffer ring_buffer(1024, 1024);
			SyslogTCPSocket* socket = new SyslogTCPSocket("127.0.0.1", 6514);
			SyslogTraceDump trace_dump(&ring_buffer, "localhost", "test", "SyslogTraceDumpTests", LOG_LOCAL0, true, 
									   socket);
		}
};

BOOST_AUTO_TEST_CASE(normal) {
		{
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
		}
};

BOOST_AUTO_TEST_SUITE_END()