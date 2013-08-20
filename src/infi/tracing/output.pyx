from libc.stdio cimport FILE, fopen, fprintf, fclose, fwrite, snprintf, stdout, stderr

cdef enum:
    TRACE_NONE   = 0
    TRACE_FILE   = 1
    TRACE_SYSLOG = 2

cdef int trace_output = TRACE_NONE

cdef FILE* trace_file_handle = NULL

cdef inline void emit_output(const char* buffer) nogil:
    global trace_output, trace_file_handle
    cdef:
        FILE* handle

    if trace_output == TRACE_SYSLOG:
        syslog(LOG_DEBUG, "%s", buffer)
    elif trace_output == TRACE_FILE:
        fprintf(trace_file_handle, "%s\n", buffer)
