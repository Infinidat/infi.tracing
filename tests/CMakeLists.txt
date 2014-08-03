cmake_minimum_required(VERSION 2.6)
project(infi.tracing)

get_filename_component(PROJECT_ROOT .. ABSOLUTE)
message(PROJECT_ROOT: ${PROJECT_ROOT})

file(GLOB_RECURSE CTRACING_FULL_PATH ${PROJECT_ROOT}/build ../build/*.so)
get_filename_component(CTRACING_FULL_PATH ${CTRACING_FULL_PATH} ABSOLUTE)
message(CTRACING_FULL_PATH: ${CTRACING_FULL_PATH})

get_filename_component(CTRACING_LIB_NAME ${CTRACING_FULL_PATH} NAME)
get_filename_component(CTRACING_LIB_PATH ${CTRACING_FULL_PATH} ABSOLUTE)
get_filename_component(CTRACING_LIB_PATH ${CTRACING_LIB_PATH} PATH)
message(CTRACING_LIB_PATH: ${CTRACING_LIB_PATH})

include_directories(../src)
include_directories(../src/infi/tracing)
link_directories(${CTRACING_LIB_PATH})

function(add_test test)
	add_executable(${test} ${test}.cpp)
	target_link_libraries(${test} :${CTRACING_FULL_PATH} python2.7 pthread)
	set_target_properties(${test} PROPERTIES COMPILE_FLAGS -g LINK_FLAGS -g)
	# set_target_properties(${test} )
endfunction()

add_test(test_file_trace_dump)
add_test(test_trace_message)
add_test(test_trace_message_ring_buffer)
add_test(test_syslog_sockets)
add_test(test_syslog_trace_dump)
add_test(test_lru)
