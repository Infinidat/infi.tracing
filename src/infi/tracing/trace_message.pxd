from libcpp cimport bool

cdef extern from "trace_message.h":
    cdef cppclass TraceMessage:
        TraceMessage() nogil
        int avail_size() nogil
        int max_size() nogil
        int limit(int size) nogil
        void unlimit(int prev_size) nogil
        void unlimit() nogil
        const char* get_buffer() nogil
        void rewind(int offset) nogil
        int write_offset() nogil
        bool write(const char* str) nogil
        bool printf(const char* fmt, ...) nogil
        bool nprintf(int max_size, const char* fmt, ...) nogil

    cdef cppclass TraceMessagePtr:
        TraceMessagePtr() nogil
        TraceMessagePtr(TraceMessage*) nogil
        TraceMessage& operator*() nogil
        TraceMessage* get() nogil
        TraceMessage* release() nogil

cdef extern from "<utility>":
    TraceMessagePtr&& move_trace_message_ptr "std::move"(TraceMessagePtr&& ptr) nogil
