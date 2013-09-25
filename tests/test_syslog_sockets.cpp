#define BOOST_TEST_MODULE SyslogSocket
#include <boost/test/unit_test.hpp>
#include <string>

#include "trace_dump.h"

using namespace std;

BOOST_AUTO_TEST_SUITE(SyslogSocketTests)

BOOST_AUTO_TEST_CASE(alloc_dealloc) {
		{
			SyslogUNIXSocket s("/dev/log");
		}

		{
			SyslogTCPSocket s("127.0.0.1", 514);
		}
};

BOOST_AUTO_TEST_CASE(connect) {
		{
			SyslogUNIXSocket s("/dev/log");
			if (s.try_connect()) {
				string msg("<7> Hello World UDP");
				s.send(msg.c_str(), msg.size());
			}
		}

		{
			SyslogTCPSocket s("127.0.0.1", 6514);
			if (s.try_connect()) {
				string msg("<7> Hello World TCP");
				s.send(msg.c_str(), msg.size());
			}
		}
};

BOOST_AUTO_TEST_SUITE_END()