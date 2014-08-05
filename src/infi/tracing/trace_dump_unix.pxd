cdef extern from "trace_dump.h":
    cdef cppclass SyslogSocket:
        SyslogSocket() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687

    cdef cppclass SyslogUNIXSocket(SyslogSocket):
        SyslogUNIXSocket() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
        SyslogUNIXSocket(const char* address) nogil

    cdef cppclass SyslogTCPSocket(SyslogSocket):
        SyslogTCPSocket() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
        SyslogTCPSocket(const char* address, int port) nogil

    # cdef cppclass SyslogUDPSocket(SyslogSocket):
    #     SyslogUDPSocket() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
    #     SyslogUDPSocket(const char* address, int port) nogil

    cdef cppclass SyslogTraceDump(TraceDump):
        SyslogTraceDump() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
        SyslogTraceDump(TraceMessageRingBuffer* ring_buffer, const char* host_name, const char* application_name,
                        const char* process_id, int facility, bool rfc5424, SyslogSocket* socket) nogil
