cdef extern from "syslog.h":
    enum:
        # openlog options
        LOG_NDELAY

    void openlog(const char* ident, int option, int facility) nogil

from trace_dump cimport SyslogTraceDump


def _trace_syslog_factory():
    global trace_dump, trace_message_ring_buffer
    trace_dump = new SyslogTraceDump(trace_message_ring_buffer)


def ctracing_set_output_to_syslog(ident, facility):
    global trace_output, trace_dump_factory_func, trace_dump_close_func
    cdef:
        const char* ident_str = ident
        int facility_int = facility
    openlog(ident_str, LOG_NDELAY, facility_int)
    trace_output = TRACE_SYSLOG
    trace_dump_factory_func = _trace_syslog_factory
    trace_dump_close_func = None