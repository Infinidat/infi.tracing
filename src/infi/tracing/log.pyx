from defs cimport *
from libc.stdio cimport snprintf

from inspect import getargvalues

cdef char* UNKNOWN_MODULE = "<unknown>"
cdef enum:
    TRACE_BUFFER_MAX_SIZE = 1024

from libc.stdio cimport FILE, fopen, fprintf, fclose, fwrite, snprintf

cdef FILE* trace_file = fopen("/tmp/trace.log", "wb")

include "serialize.pyx"

cdef inline int serialize_prefix(char direction, long gid, long depth, PyFrameObject* frame, char* output, 
    int maxlen) with gil:
    cdef:
        char* file_name
        char* func_name
        char* module_name

    line_no = PyFrame_GetLineNumber(frame)
    file_name = PyString_AsString(frame.f_code.co_filename)
    func_name = PyString_AsString(frame.f_code.co_name)

    module_name_obj = (<object> frame.f_globals).get('__name__')
    if module_name_obj is not None:
        module_name = PyString_AsString(<PyObject*>module_name_obj)
    else:
        module_name = UNKNOWN_MODULE

    return snprintf(output, maxlen, "%c,%d:%d,%s:%d,%s,%s", direction, gid, depth, file_name, line_no, module_name, 
                    func_name)

cdef void log_call(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    cdef:
        int locals_i = 0
        int line_no
        char trace_buffer[TRACE_BUFFER_MAX_SIZE + 1]
        int trace_buffer_len = 0
        int trace_buffer_i = 0
        int bytes_written = 0

    trace_buffer[TRACE_BUFFER_MAX_SIZE] = '\0'
    trace_buffer_i = serialize_prefix('>', gid, depth, frame, trace_buffer, TRACE_BUFFER_MAX_SIZE)
    if trace_level > TRACE_FUNC_NAME:
        with gil:
            for locals_i in range(frame.f_code.co_argcount):
                trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, ",")
                trace_buffer_i += fast_repr(frame.f_localsplus[locals_i], &trace_buffer[trace_buffer_i], 
                                            TRACE_BUFFER_MAX_SIZE - trace_buffer_i)

            locals_i = frame.f_code.co_argcount
            if frame.f_code.co_flags & CO_VARARGS:
                trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, ",")
                trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, "vargs=")
                trace_buffer_i += fast_repr(frame.f_localsplus[locals_i], &trace_buffer[trace_buffer_i], 
                                            TRACE_BUFFER_MAX_SIZE - trace_buffer_i)
                inc(locals_i)

            if frame.f_code.co_flags & CO_VARKEYWORDS:
                trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, ",")
                trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, "kwargs=")
                trace_buffer_i += fast_repr(frame.f_localsplus[locals_i], &trace_buffer[trace_buffer_i], 
                                            TRACE_BUFFER_MAX_SIZE - trace_buffer_i)
                inc(locals_i)

    fwrite(trace_buffer, trace_buffer_i, 1, trace_file)
    fwrite("\n", 1, 1, trace_file)


cdef void log_return(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    cdef:
        char trace_buffer[TRACE_BUFFER_MAX_SIZE + 1]
        int trace_buffer_len = 0
        int trace_buffer_i = 0
        int bytes_written = 0

    trace_buffer[TRACE_BUFFER_MAX_SIZE] = '\0'
    trace_buffer_i = serialize_prefix('<', gid, depth, frame, trace_buffer, TRACE_BUFFER_MAX_SIZE)
    if trace_level > TRACE_FUNC_NAME:
        trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, ",")
        with gil:
            if arg != NULL:
                trace_buffer_i += fast_repr(arg, &trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i)
            else:
                # FIXME: extract exception info here and serialize it
                trace_buffer_i += snprintf(&trace_buffer[trace_buffer_i], TRACE_BUFFER_MAX_SIZE - trace_buffer_i, 
                                           "EXCEPTION")
    fwrite(trace_buffer, trace_buffer_i, 1, trace_file)
    fwrite("\n", 1, 1, trace_file)