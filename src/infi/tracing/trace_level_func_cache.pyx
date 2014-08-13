cdef extern from "lru.hpp":
    cdef cppclass LRU:
        void insert(unsigned long key, int value) nogil
        int find(unsigned long key) nogil

cdef unsigned long func_cache_hit, func_cache_miss

cdef inline int call_filter_and_store_trace_level(PyObject* filter_func, PyFrameObject* frame, LRU* trace_level_lru) with gil:
    cdef int trace_level

    trace_level_result = (<object>filter_func)(<object>frame)
    if trace_level_result is None:
        # TODO this is an error and we should log it.
        import sys
        sys.stderr.write("infi.tracing: filter returned None for frame: {} (filter: {})\n".format(<object>frame.f_code,
                                                                                                  <object>filter_func))
        trace_level_result = NO_TRACE
    trace_level = int(trace_level_result)
    trace_level_lru.insert(<long>frame.f_code, trace_level_result)
    return trace_level


cdef inline int find_trace_level_or_call_filter(PyFrameObject* frame, PyObject* filter_func, LRU* trace_level_lru) nogil:
    cdef int trace_level

    trace_level = trace_level_lru.find(<long>frame.f_code)
    if trace_level != -1:
        inc(func_cache_hit)
    else:
        trace_level = call_filter_and_store_trace_level(filter_func, frame, trace_level_lru)
        inc(func_cache_miss)
    return trace_level
