#include <string>

#include "trace_dump.h"
#include "test_utils.h"

using namespace std;

bool test_alloc_dealloc() {
	{
		SyslogUNIXSocket s("/dev/log");
	}

	{
		SyslogTCPSocket s("127.0.0.1", 514);
	}
	return true;
};

bool test_connect() {
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
	return true;
};


MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_connect);
MAIN_TEST_CASE_END
