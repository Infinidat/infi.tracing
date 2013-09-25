#!/bin/bash
# NOTE: This only works on Ubuntu for now.
set -e

cd `dirname $0`
mkdir -p build

gcc -o build/boost_version -x c++ - <<EOF
#include <boost/version.hpp>
#include <stdio.h>

int main(int, char*[]) {
    printf("%d.%d.%d\n", BOOST_VERSION / 100000, BOOST_VERSION / 100 % 1000, BOOST_VERSION % 100);
    return 0;
}
EOF
boost_ver=`./build/boost_version`

CFLAGS="-g -DBOOST_TEST_DYN_LINK=1"
CTRACING_INC="-I../src/infi/tracing"
CTRACING_LIB="-L../src/infi/tracing -l:ctracing.so"
BOOST_LIB="-l:libboost_thread.so.${boost_ver} -l:libboost_chrono.so.${boost_ver} -l:libboost_unit_test_framework.so.${boost_ver} -l:libboost_system.so.${boost_ver}"
PYTHON_LIB="-L../parts/python/lib -lpython2.7"

g++ $CFLAGS $CTRACING_INC test_trace_message.cpp $CTRACING_LIB $BOOST_LIB -o build/test_trace_message
echo "test_trace_message"
./build/test_trace_message

g++ $CFLAGS $CTRACING_INC test_syslog_sockets.cpp $CTRACING_LIB $BOOST_LIB $PYTHON_LIB -o build/test_syslog_sockets
echo "test_syslog_sockets"
./build/test_syslog_sockets

g++ $CFLAGS $CTRACING_INC test_syslog_trace_dump.cpp $CTRACING_LIB $BOOST_LIB $PYTHON_LIB -o build/test_syslog_trace_dump
echo "test_syslog_trace_dump"
./build/test_syslog_trace_dump

g++ $CFLAGS $CTRACING_INC test_file_trace_dump.cpp $CTRACING_LIB $BOOST_LIB $PYTHON_LIB -o build/test_file_trace_dump
echo "test_file_trace_dump"
./build/test_file_trace_dump
