from defs cimport *
from libc.stdio cimport snprintf

from inspect import getargvalues

cdef char* UNKNOWN_MODULE = "<unknown>"
cdef enum:
    TRACE_BUFFER_MAX_SIZE = 1024

from libc.stdio cimport FILE, fopen, fprintf, fclose

cdef FILE* trace_file = fopen("/tmp/trace.log", "wb")

cdef void log_call(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    cdef:
        int line_no
        char* file_name
        char* func_name
        char* module_name
        char trace_buffer[TRACE_BUFFER_MAX_SIZE]
        int trace_buffer_len = 0

    with gil:
        line_no = PyFrame_GetLineNumber(frame)
        file_name = PyString_AsString(frame.f_code.co_filename)
        func_name = PyString_AsString(frame.f_code.co_name)

        module_name_obj = (<object> frame.f_globals).get('__name__')
        if module_name_obj is not None:
            module_name = PyString_AsString(<PyObject*>module_name_obj)
        else:
            module_name = UNKNOWN_MODULE

        # args = getargvalues(<object>frame)

        # snprintf(trace_buffer, TRACE_BUFFER_MAX_SIZE, "> %d:%d %s.%s %s:%d", gid, depth, module_name, func_name,
        #          file_name, line_no)

        # fprintf(trace_file, "> %d:%d %s.%s %s:%d\n", gid, depth, module_name, func_name,
        #         file_name, line_no)

        # try:
        #     pretty_argument_spec = formatargvalues(*getargvalues(<object>frame))
        #     if pretty_argument_spec > 256:
        #         pretty_argument_spec = str(pretty_argument_spec)[0:256] + "...)"
        # except:
        #     pretty_argument_spec = "(...)"
        # log_str = "{} ({}) > {}{} {}:{}".format(gid, depth, <object>name, pretty_argument_spec, <object>fname, line_no)

        # call_log.append((0, gid, depth, "{}:{}:{}".format(<object>name, <object> fname, line_no)))
        # call_log.append((0, gid, depth, <object>name, <object>fname, line_no))
        # print("> ({}:{}) {} [{}:{}]".format(gid, depth, <object>name, <object>fname, line_no))


cdef void log_return(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    global call_log
    cdef:
        int line_no
        char* file_name
        char* func_name
        char* module_name
        char trace_buffer[TRACE_BUFFER_MAX_SIZE]
        int trace_buffer_len = 0

    with gil:
        line_no = PyFrame_GetLineNumber(frame)
        file_name = PyString_AsString(frame.f_code.co_filename)
        func_name = PyString_AsString(frame.f_code.co_name)

        module_name_obj = (<object> frame.f_globals).get('__name__')
        if module_name_obj is not None:
            module_name = PyString_AsString(<PyObject*>module_name_obj)
        else:
            module_name = UNKNOWN_MODULE

        # snprintf(trace_buffer, TRACE_BUFFER_MAX_SIZE, "> %d:%d %s.%s %s:%d", gid, depth, module_name, func_name,
        #          file_name, line_no)

        # fprintf(trace_file, "< %d:%d %s.%s %s:%d\n", gid, depth, module_name, func_name,
        #         file_name, line_no)

        # if arg == NULL:
        #     # call_log.append((1, gid, depth, "E {}:{}:{}".format(<object>name, <object> fname, line_no)))
        #     # call_log.append((1, gid, depth, <object>name, <object>fname, line_no, None))

        #     log_str = "{} ({}) > {} = ERROR {}:{}".format(gid, depth, <object>name, <object>fname, line_no)
        # else:
        #     try:
        #         return_value = repr(<object>arg)
        #         if len(return_value) > 256:
        #             return_value = object.__repr__(<object>arg)
        #     except:
        #         return_value = "(...)"

        #     log_str = "{} ({}) > {} = {} {}:{}".format(gid, depth, <object>name, return_value, <object>fname, line_no)
            # call_log.append((1, gid, depth, "{}:{}:{}".format(<object>name, <object> fname, line_no)))
            # call_log.append((1, gid, depth, <object>name, <object>fname, line_no, <object>arg))

    # if arg == NULL:
    #     with gil:
    #         print("< ({}:{}) {} : NULL (Exception)".format(gid, depth, (<object>frame.f_code).co_name))
    # else:
    #     with gil:
    #         print("< ({}:{}) {} : {}".format(gid, depth, (<object>frame.f_code).co_name, <object>arg))

