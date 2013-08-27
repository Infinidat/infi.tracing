from defs cimport *
from trace_message cimport TraceMessage

include "ctracing_log_serialize.pyx"

cdef char* UNKNOWN_MODULE = "<unknown>"


cdef inline bool serialize_prefix(char direction, long gid, long depth, PyFrameObject* frame, 
                                  TraceMessage* message) with gil:
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

    return message.printf("%c,%d:%d,%s:%d,%s,%s", direction, gid, depth, file_name, line_no, module_name, func_name)


cdef void log_call(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    global trace_message_ring_buffer
    cdef:
        int locals_i = 0
        TraceMessage* trace_message = trace_message_ring_buffer.reserve_push()

    if trace_message == NULL:
        return

    try:
        if not serialize_prefix('>', gid, depth, frame, trace_message):
            # TODO: not enough room to write this down, maybe we should write TRUNCATED or something like that.
            return

        if trace_level > TRACE_FUNC_NAME:
            with gil:
                for locals_i in range(frame.f_code.co_argcount):
                    trace_message.write(",")
                    fast_repr(frame.f_localsplus[locals_i], trace_message)

                locals_i = frame.f_code.co_argcount
                if frame.f_code.co_flags & CO_VARARGS:
                    trace_message.write(",vargs=")
                    fast_repr(frame.f_localsplus[locals_i], trace_message)
                    inc(locals_i)

                if frame.f_code.co_flags & CO_VARKEYWORDS:
                    trace_message.write(",kwargs=")
                    fast_repr(frame.f_localsplus[locals_i], trace_message)
                    inc(locals_i)
    finally:
        trace_message_ring_buffer.commit_push(trace_message)

cdef void log_return(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    global trace_message_ring_buffer
    cdef TraceMessage* trace_message = trace_message_ring_buffer.reserve_push()
    cdef PyObject* exc_type = frame.f_tstate.exc_type
    cdef PyObject* exc_value = frame.f_tstate.exc_value

    if trace_message == NULL:
        return        

    try:
        if not serialize_prefix('<', gid, depth, frame, trace_message):
            # TODO: not enough room to write this down, maybe we should write TRUNCATED or something like that.
            return

        if trace_level > TRACE_FUNC_NAME:
            trace_message.write(",")
            with gil:
                if arg != NULL:
                    fast_repr(arg, trace_message)
                else:
                    # Since we're using setprofile, we can't know what exception was raised because Python's code
                    # (specifically ceval.c:call_trace_protected) masks the exception before calling us - it calls
                    # PyErr_Fetch that clears the exception from the frame.
                    trace_message.write("exc")
    finally:
        trace_message_ring_buffer.commit_push(trace_message)
