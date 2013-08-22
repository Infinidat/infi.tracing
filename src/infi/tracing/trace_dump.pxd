from libc.stdio cimport FILE

from trace_message_ring_buffer cimport TraceMessageRingBuffer

cdef extern from "trace_dump.h":
    cdef cppclass TraceDump:
        TraceDump() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
        TraceDump(TraceMessageRingBuffer& ring_buffer) nogil
        void start() nogil
        void stop() nogil

    cdef cppclass SyslogTraceDump(TraceDump):
        SyslogTraceDump(TraceMessageRingBuffer& ring_buffer) nogil

    cdef cppclass FileTraceDump(TraceDump):
        FileTraceDump(TraceMessageRingBuffer& ring_buffer, FILE* f) nogil