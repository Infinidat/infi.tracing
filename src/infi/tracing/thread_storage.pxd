from libcpp cimport bool

cdef extern from "thread_storage.h":
    cdef enum: NO_TRACE_FROM_DEPTH_DISABLED "NO_TRACE_FROM_DEPTH_DISABLED"

    cdef cppclass GreenletStorage:
        long gid
        long depth
        long no_trace_from_depth
        bool enabled

    cdef cppclass ThreadStorage:
        unsigned long id
        int enabled
        long last_frame
        long last_gid
        GreenletStorage* last_gstorage

        GreenletStorage* find_gstorage(long gid) nogil
        GreenletStorage* new_gstorage(long gid) nogil
        GreenletStorage* del_gstorage(long gid) nogil

    ThreadStorage* get_thread_storage() nogil
    void init_thread_storage_once() nogil
