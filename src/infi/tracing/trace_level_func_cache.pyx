cdef extern from "lru.hpp" namespace "plb":
    cdef cppclass LRUCacheH4ConstIterator[K, V]:
        const K& key() nogil
        const V& value() nogil
        bool operator==(const LRUCacheH4ConstIterator[K, V]& other) nogil
        bool operator!=(const LRUCacheH4ConstIterator[K, V]& other) nogil

    cdef cppclass LRUCacheH4[K, V]:
        LRUCacheH4(int)
        LRUCacheH4ConstIterator[K, V] find(const K& key) nogil
        LRUCacheH4ConstIterator[K, V] end() nogil
        void insert(const K& key, const V& value) nogil


ctypedef LRUCacheH4[long,int] CodeLRUCache
ctypedef LRUCacheH4ConstIterator[long,int] CodeLRUCacheConstIterator

cdef CodeLRUCache* trace_level_func_cache = NULL
cdef unsigned long func_cache_hit, func_cache_miss

cdef inline int call_filter_and_store_trace_level(PyObject* filter_func, PyFrameObject* frame) with gil:
    global trace_level_func_cache
    cdef int trace_level

    trace_level_result = (<object>filter_func)(<object>frame)
    if trace_level_result is None:
        # TODO this is an error and we should log it.
        import sys
        sys.stderr.write("infi.tracing: filter returned None for frame: {} (filter: {})".format(<object>frame.f_code, 
                                                                                                <object>filter_func))
        trace_level_result = TRACE_NONE
    trace_level = int(trace_level_result)
    trace_level_func_cache.insert(<long>frame.f_code, trace_level_result)
    return trace_level


cdef inline int find_trace_level_or_call_filter(PyFrameObject* frame, PyObject* filter_func) nogil:
    global trace_level_func_cache
    cdef int trace_level
    cdef CodeLRUCacheConstIterator code_found

    code_found = trace_level_func_cache.find(<long>frame.f_code)
    if code_found != trace_level_func_cache.end():
        trace_level = code_found.value()
        inc(func_cache_hit)
    else:
        trace_level = call_filter_and_store_trace_level(filter_func, frame)
        inc(func_cache_miss)
    return trace_level
