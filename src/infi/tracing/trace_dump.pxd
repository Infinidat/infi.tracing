from libc.stdio cimport FILE
from libcpp cimport bool

from trace_message_ring_buffer cimport TraceMessageRingBuffer

cdef extern from "trace_dump.h":
    cdef cppclass TraceDump:
        TraceDump() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
        TraceDump(TraceMessageRingBuffer* ring_buffer) nogil
        void start() nogil
        void stop() nogil

    cdef cppclass SyslogTraceDump(TraceDump):
        SyslogTraceDump() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687

    # Cython doesn't handle static methods very well, so this is a hack:
    cdef SyslogTraceDump* SyslogTraceDump_create_with_unix_socket "SyslogTraceDump::create_with_unix_socket"(
        TraceMessageRingBuffer* ring_buffer, const char* host_name, const char* application_name,
        const char* process_id, int facility, bool rfc5424, const char* address) nogil

    cdef SyslogTraceDump* SyslogTraceDump_create_with_tcp_socket "SyslogTraceDump::create_with_tcp_socket"(
        TraceMessageRingBuffer* ring_buffer, const char* host_name, const char* application_name,
        const char* process_id, int facility, bool rfc5424, const char* address, int port) nogil

    cdef cppclass FileTraceDump(TraceDump):
        FileTraceDump(TraceMessageRingBuffer* ring_buffer, FILE* f, bool close_handle) nogil
