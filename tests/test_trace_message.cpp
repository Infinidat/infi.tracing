#include <string>

#include "trace_message.h"
#include "test_utils.h"

using namespace std;

bool test_alloc_dealloc() {
	{
		TraceMessage msg_default;
		ASSERT_EQ(msg_default.max_size(), 0);
		ASSERT_EQ(msg_default.avail_size(), 0);
		ASSERT_EQ(msg_default.write_offset(), 0);
		ASSERT_EQ(msg_default.get_severity(), SEVERITY_NOTSET);
	}

	{
		TraceMessage msg_with_capacity(128);
		ASSERT_EQ(msg_with_capacity.max_size(), 128);
		ASSERT_EQ(msg_with_capacity.avail_size(), 128);
		ASSERT_EQ(msg_with_capacity.write_offset(), 0);
		ASSERT_EQ(msg_with_capacity.get_severity(), SEVERITY_NOTSET);
	}
	return true;
}

bool test_realloc() {
	{
		TraceMessage msg;
		msg.realloc(256);
		ASSERT_EQ(msg.max_size(), 256);
		ASSERT_EQ(msg.write_offset(), 0);
	}

	{
		TraceMessage msg(128);
		msg.write("hello world");
		msg.realloc(256);
		ASSERT_EQ(msg.max_size(), 256);
		ASSERT_EQ(msg.write_offset(), 0);
	}
	return true;
};

bool test_write() {
	TraceMessage msg(32);

	string d1("hello world");
	ASSERT(msg.write(d1.c_str()));
	ASSERT_EQ(string(msg.get_buffer()), d1);
	ASSERT_EQ(msg.write_offset(), d1.size());

	string d2(32 - d1.size() + 1, 'x');
	ASSERT(! msg.write(d2.c_str()));
	return true;
}

bool test_operator_eq() {
	TraceMessage msg(32);

	string d1("hello world");
	ASSERT(msg.write(d1.c_str()));
	ASSERT_EQ(string(msg.get_buffer()), d1);

	TraceMessage msg2(32);
	ASSERT_EQ(string(msg2.get_buffer()), string());
	msg2 = msg;
	ASSERT_EQ(string(msg2.get_buffer()), d1);
	return true;
}

MAIN_TEST_CASE_BEGIN
	TEST(test_alloc_dealloc);
	TEST(test_realloc);
	TEST(test_write);
	TEST(test_operator_eq);
MAIN_TEST_CASE_END