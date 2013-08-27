from libc.stdio cimport FILE, fopen, fclose, stdout, stderr
from trace_dump cimport FileTraceDump

cdef FILE* trace_file_handle = NULL


def _trace_file_factory():
    global trace_dump, trace_message_ring_buffer, trace_file_handle
    trace_dump = new FileTraceDump(trace_message_ring_buffer, trace_file_handle)


def _trace_file_close():
    global trace_output, trace_file_handle
    if trace_output == TRACE_FILE and trace_file_handle != NULL:
        fclose(trace_file_handle)
        trace_file_handle = NULL


def ctracing_set_output_to_file(path):
    global trace_output, trace_file_handle, trace_dump_factory_func, trace_dump_close_func
    
    if trace_file_handle != NULL:
        raise ValueError("already have an open trace file")

    trace_file_handle = fopen(path, "wb")
    if trace_file_handle == NULL:
        raise ValueError("failed to open trace file {} for writing".format(path))

    trace_output = TRACE_FILE
    trace_dump_factory_func = _trace_file_factory
    trace_file_close_func = _trace_file_close


def ctracing_set_output_to_stdout():
    global stdout
    ctracing_set_output_to_file_handle(TRACE_STDOUT, stdout)


def ctracing_set_output_to_stderr():
    global stderr
    ctracing_set_output_to_file_handle(TRACE_STDERR, stderr)


cdef ctracing_set_output_to_file_handle(output_type, FILE* handle):
    global trace_output, trace_file_handle, trace_dump_factory_func, trace_dump_close_func

    if trace_file_handle != NULL:
        raise ValueError("already have an open trace file")

    trace_output = output_type
    trace_file_handle = handle
    trace_file_close_func = _trace_file_close
