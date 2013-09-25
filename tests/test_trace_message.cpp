#define BOOST_TEST_MODULE TraceMessage
#include <boost/test/unit_test.hpp>
#include <string>

#include "trace_message.h"

using namespace std;

BOOST_AUTO_TEST_SUITE(TraceMessageTests)

BOOST_AUTO_TEST_CASE(alloc_dealloc) {
		{
			TraceMessage msg_default;
			BOOST_CHECK_EQUAL(msg_default.max_size(), 0);
			BOOST_CHECK_EQUAL(msg_default.avail_size(), 0);
			BOOST_CHECK_EQUAL(msg_default.write_offset(), 0);
			BOOST_CHECK_EQUAL(msg_default.get_severity(), SEVERITY_NOTSET);
		}

		{
			TraceMessage msg_with_capacity(128);
			BOOST_CHECK_EQUAL(msg_with_capacity.max_size(), 128);
			BOOST_CHECK_EQUAL(msg_with_capacity.avail_size(), 128);
			BOOST_CHECK_EQUAL(msg_with_capacity.write_offset(), 0);
			BOOST_CHECK_EQUAL(msg_with_capacity.get_severity(), SEVERITY_NOTSET);
		}
};

BOOST_AUTO_TEST_CASE(realloc) {
	{
		TraceMessage msg;
		msg.realloc(256);
		BOOST_CHECK_EQUAL(msg.max_size(), 256);
		BOOST_CHECK_EQUAL(msg.write_offset(), 0);	}

	{
		TraceMessage msg(128);
		msg.write("hello world");
		msg.realloc(256);
		BOOST_CHECK_EQUAL(msg.max_size(), 256);
		BOOST_CHECK_EQUAL(msg.write_offset(), 0);		
	}
};

BOOST_AUTO_TEST_CASE(write) {
	TraceMessage msg(32);

	string d1("hello world");
	BOOST_CHECK(msg.write(d1.c_str()));
	BOOST_CHECK_EQUAL(string(msg.get_buffer()), d1);	
	BOOST_CHECK_EQUAL(msg.write_offset(), d1.size());

	string d2(32 - d1.size() + 1, 'x');
	BOOST_CHECK(! msg.write(d2.c_str()));
}

BOOST_AUTO_TEST_CASE(operator_eq) {
	TraceMessage msg(32);

	string d1("hello world");
	BOOST_CHECK(msg.write(d1.c_str()));
	BOOST_CHECK_EQUAL(string(msg.get_buffer()), d1);	

	TraceMessage msg2(32);
	BOOST_CHECK_EQUAL(string(msg2.get_buffer()), string());
	msg2 = msg;
	BOOST_CHECK_EQUAL(string(msg2.get_buffer()), d1);
}

BOOST_AUTO_TEST_SUITE_END()