cdef CodeLRUCache* trace_level_func_cache = NULL

cdef inline int call_filter_and_store_trace_level(PyObject* filter_func, PyFrameObject* frame) with gil:
    global trace_level_func_cache
    cdef int trace_level

    trace_level_result = (<object>filter_func)(<object>frame.f_code)
    if trace_level_result is None:
        print("trace_level_result is None w/ frame: {} (filter: {})".format(<object>frame.f_code, <object>filter_func))
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
    else:
        trace_level = call_filter_and_store_trace_level(filter_func, frame)
    return trace_level
