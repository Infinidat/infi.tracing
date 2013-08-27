from trace_dump cimport TraceDump

cdef enum:
    TRACE_NONE   = 0
    TRACE_FILE   = 1
    TRACE_STDOUT = 2
    TRACE_STDERR = 3
    TRACE_SYSLOG = 4

# Methods in ctracing_trace_dump_xxx fill the following variables (we do it this way because we're too lazy to properly
# define Cython types):
cdef int trace_output = TRACE_NONE
cdef TraceDump* trace_dump = NULL
trace_dump_factory_func = None
trace_dump_close_func = None

include "ctracing_trace_dump_file.pyx"
include "ctracing_trace_dump_syslog.pyx"

def ctracing_start_trace_dump():
    global trace_dump, trace_output
    if trace_dump != NULL:
        raise ValueError("trace dump already started")

    if trace_dump_factory_func:
        trace_dump_factory_func()

    if trace_dump != NULL:
        trace_dump.start()
    

def ctracing_stop_trace_dump():
    global trace_dump, trace_file_handle
    if trace_dump != NULL:
        trace_dump.stop()
        del trace_dump
        trace_dump = NULL

    if trace_dump_close_func:
        trace_dump_close_func()
