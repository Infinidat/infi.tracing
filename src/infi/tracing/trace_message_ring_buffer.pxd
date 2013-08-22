from libcpp cimport bool
from trace_message cimport TraceMessage

cdef extern from "trace_message_ring_buffer.h":
    cdef cppclass TraceMessageRingBuffer:
        TraceMessageRingBuffer() nogil
        
        TraceMessage* reserve_push() nogil
        void commit_push(TraceMessage* message) nogil

        TraceMessage* reserve_pop(long timeout_in_millis) nogil
        void commit_pop() nogil

        bool is_full() nogil
        bool is_empty() nogil

        unsigned long get_overflow_counter() nogil