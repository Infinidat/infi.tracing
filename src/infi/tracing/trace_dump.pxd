from libcpp cimport bool
from libc.stdio cimport FILE

from trace_message cimport TraceMessagePtr

cdef extern from "trace_dump.h":
    cdef cppclass TraceDump:
        void start() nogil
        void stop() nogil
        void push(TraceMessagePtr&& ptr) nogil
        void begin_shutdown() nogil

    cdef cppclass SyslogTraceDump(TraceDump):
        pass

    cdef cppclass FileTraceDump(TraceDump):
        FileTraceDump(FILE* f) nogil