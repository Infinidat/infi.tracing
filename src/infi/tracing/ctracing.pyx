from defs cimport *

DEFAULT_FUNC_CACHE_SIZE = 10000

cdef CodeLRUCache* lru_cache = NULL

cdef int trace_func(PyObject* obj, PyFrameObject* frame, int what, PyObject* arg) nogil:
    cdef:
        int should_trace = 0
        int thread_id = -1
        CodeLRUCacheConstIterator code_found

    code_found = lru_cache.find(<long>frame.f_code)
    should_trace = False
    if code_found != lru_cache.end():
        should_trace = code_found.value()
    else:
        with gil:
            should_trace = int(should_trace_code(<object>frame.f_code))
        lru_cache.insert(<long>frame.f_code, <int>should_trace)

    if not should_trace:
        return 0

    thread_id = pthread_self()

    with gil:
        greenlet = PyGreenlet_GetCurrent()
        greenlet_id = <long>greenlet
        # print(<object>frame.f_code.co_name)

    if what == PyTrace_CALL:  # arg is NULL
        # with gil:
        #     print("> ", PyFrame_GetLineNumber(frame))
        pass
    elif what == PyTrace_EXCEPTION:  # arg is the tuple returned from sys.exc_info()
        pass
    elif what == PyTrace_RETURN:  # arg is value returned to the caller
        # with gil:
        #     print("< ", PyFrame_GetLineNumber(frame))
        pass
    elif what == PyTrace_C_CALL:  # arg is C function called
        pass
    elif what == PyTrace_C_EXCEPTION:  # arg is NULL
        pass
    elif what == PyTrace_C_RETURN:  # arg is NULL
        pass
    return 0


def _should_trace_code(code):
    return False

should_trace_code = _should_trace_code

def ctracing_set_profile(filter_func):
    PyGreenlet_Import()
    if lru_cache == NULL:
        ctracing_set_func_cache_size(DEFAULT_FUNC_CACHE_SIZE)
    PyEval_SetProfile(trace_func, <PyObject*>filter_func)

def ctracing_set_func_cache_size(size):
    global lru_cache
    assert size >= 0

    if lru_cache != NULL:
        del lru_cache

    lru_cache = new CodeLRUCache(size)
