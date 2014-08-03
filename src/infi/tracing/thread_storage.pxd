from libcpp cimport bool

cdef extern from "lru.hpp":
    cdef cppclass LRU:
        void insert(unsigned long key, int value)
        int find(unsigned long key)

cdef extern from "thread_storage.h":
    cdef enum: NO_TRACE_FROM_DEPTH_DISABLED "NO_TRACE_FROM_DEPTH_DISABLED"

    cdef cppclass GreenletStorage:
        long gid
        long depth
        long no_trace_from_depth
        int trace_level
        bool enabled
        LRU trace_level_lru

    cdef cppclass ThreadStorage:
        unsigned long id
        int enabled
        long last_frame
        long last_gid
        GreenletStorage* last_gstorage

        GreenletStorage* find_gstorage(long gid) nogil
        GreenletStorage* new_gstorage(long gid) nogil
        void del_gstorage(GreenletStorage* ptr) nogil

    ThreadStorage* get_thread_storage() nogil
    void init_thread_storage_once(size_t trace_level_lru_capacity) nogil
