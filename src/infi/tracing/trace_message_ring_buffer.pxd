from libcpp cimport bool
from trace_message cimport TraceMessage

cdef extern from "trace_message_ring_buffer.h":
    cdef cppclass TraceMessageRingBuffer:
        TraceMessageRingBuffer() nogil
        
        TraceMessage* reserve_push() nogil
        void commit_push(TraceMessage* message) nogil

        unsigned long get_overflow_counter() nogil
        unsigned long get_spinlock_consumer_wait_counter() nogil
        unsigned long get_spinlock_producer_wait_counter() nogil