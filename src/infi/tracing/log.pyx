from defs cimport *
from trace_message cimport TraceMessage, TraceMessagePtr, move_trace_message_ptr

include "serialize.pyx"

cdef char* UNKNOWN_MODULE = "<unknown>"
cdef enum:
    TRACE_BUFFER_MAX_SIZE = 1024


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
    global trace_dump
    # cdef:
    #     int locals_i = 0
    #     TraceMessagePtr trace_message = TraceMessagePtr(new TraceMessage())

    # if not serialize_prefix('>', gid, depth, frame, trace_message.get()):
    #     # FIXME - not enough room to write this down...
    #     return

    # if trace_level > TRACE_FUNC_NAME:
    #     with gil:
    #         for locals_i in range(frame.f_code.co_argcount):
    #             trace_message.get().write(",")
    #             fast_repr(frame.f_localsplus[locals_i], trace_message.get())

    #         locals_i = frame.f_code.co_argcount
    #         if frame.f_code.co_flags & CO_VARARGS:
    #             trace_message.get().write(",vargs=")
    #             fast_repr(frame.f_localsplus[locals_i], trace_message.get())
    #             inc(locals_i)

    #         if frame.f_code.co_flags & CO_VARKEYWORDS:
    #             trace_message.get().write(",kwargs=")
    #             fast_repr(frame.f_localsplus[locals_i], trace_message.get())
    #             inc(locals_i)

    # if trace_dump != NULL:
    #     trace_dump.push(move_trace_message_ptr(trace_message))


cdef void log_return(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    global trace_dump
    # cdef TraceMessagePtr trace_message = TraceMessagePtr(new TraceMessage())

    # if not serialize_prefix('<', gid, depth, frame, trace_message.get()):
    #     # FIXME - not enough room to write this down...
    #     return

    # if trace_level > TRACE_FUNC_NAME:
    #     trace_message.get().write(",")
    #     with gil:
    #         if arg != NULL:
    #             fast_repr(arg, trace_message.get())
    #         else:
    #             # FIXME: extract exception info here and serialize it
    #             trace_message.get().write("EXCEPTION")
    
    # if trace_dump != NULL:
    #     trace_dump.push(move_trace_message_ptr(trace_message))
