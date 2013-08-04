from defs cimport *

DEFAULT_FUNC_CACHE_SIZE = 10000

cdef enum:
    NO_TRACE              = 0
    NO_TRACE_NESTED       = 1
    TRACE_FUNC_NAME       = 2
    TRACE_FUNC_PRIMITIVES = 3
    TRACE_FUNC_REPR       = 4

cdef:
    CodeLRUCache* trace_level_func_cache = NULL
    pthread_key_t depth_key
    pthread_key_t nested_no_trace_depth_key

cdef long current_depth() nogil:
    return <long>pthread_getspecific(depth_key)

cdef void set_depth(long depth) nogil:
    pthread_setspecific(depth_key, <void*>depth)

cdef long nested_no_trace_depth() nogil:
    return <long>pthread_getspecific(nested_no_trace_depth_key)

cdef void set_nested_no_trace_depth(long depth) nogil:
    pthread_setspecific(nested_no_trace_depth_key, <void*>depth)


cdef int trace_func(PyObject* filter_func, PyFrameObject* frame, int what, PyObject* arg) nogil:
    cdef:
        int trace_level = NO_TRACE
        long depth = -1
        long no_trace_depth = -1
        long thread_id = -1
        CodeLRUCacheConstIterator code_found

    depth = current_depth()
    no_trace_depth = nested_no_trace_depth()

    if what == PyTrace_CALL:
        depth += 1
        set_depth(depth)
    elif (what == PyTrace_EXCEPTION) or (what == PyTrace_RETURN):
        # depth -= 1
        set_depth(depth - 1)


    if no_trace_depth != -1:
        if no_trace_depth < depth:
            return 0
        else:
            set_nested_no_trace_depth(-1)

    code_found = trace_level_func_cache.find(<long>frame.f_code)
    if code_found != trace_level_func_cache.end():
        trace_level = code_found.value()
    else:
        with gil:
            trace_level = int((<object>filter_func)(<object>frame.f_code))
            print("filter returned trace level: {}".format(trace_level))
        trace_level_func_cache.insert(<long>frame.f_code, trace_level)

    if trace_level == NO_TRACE:
        return 0
    elif trace_level == NO_TRACE_NESTED:
        set_nested_no_trace_depth(depth)
        return 0

    with gil:
        print("depth={} no_trace_depth={} trace_level={}".format(depth, no_trace_depth, trace_level))

    thread_id = pthread_self()

    if _PyGreenlet_API != NULL:
        with gil:
            greenlet = PyGreenlet_GetCurrent()
            greenlet_id = <long>greenlet
    
    if what == PyTrace_CALL:  # arg is NULL
        with gil:
            print("> ({}) {}".format(depth, (<object>frame.f_code).co_name))
    elif what == PyTrace_EXCEPTION:  # arg is the tuple returned from sys.exc_info()
        with gil:
            print("< ({}) Exception".format(depth, (<object>frame.f_code).co_name))
    elif what == PyTrace_RETURN:  # arg is value returned to the caller
        if arg == NULL:
            with gil:
                print("< ({}) {} : NULL (Exception)".format(depth, (<object>frame.f_code).co_name))
        else:
            with gil:
                print("< ({}) {} : {}".format(depth, (<object>frame.f_code).co_name, <object>arg))

    # We don't trace through C calls.    
    # elif what == PyTrace_C_CALL:  # arg is C function called
    #     pass
    # elif what == PyTrace_C_EXCEPTION:  # arg is NULL
    #     pass
    # elif what == PyTrace_C_RETURN:  # arg is NULL
    #     pass
    return 0


ctracing_initialized = False

def ctracing_set_profile(filter_func):
    global ctracing_initialized
    if not ctracing_initialized:  # GIL already taken, no race conditions
        ctracing_initialized = True
        result = pthread_key_create(&depth_key, NULL)
        if result != 0:
            raise Exception("Failed to initiailize pthread local storage")
        result = pthread_key_create(&nested_no_trace_depth_key, NULL)
        if result != 0:
            raise Exception("Failed to initiailize pthread local storage")
        set_nested_no_trace_depth(-1)

    if filter_func is None:
        raise ValueError("filter_func cannot be None")

    PyGreenlet_Import()
    if trace_level_func_cache == NULL:
        ctracing_set_func_cache_size(DEFAULT_FUNC_CACHE_SIZE)
    PyEval_SetProfile(trace_func, <PyObject*>filter_func)


def ctracing_set_func_cache_size(size):
    global trace_level_func_cache
    assert size >= 0

    if trace_level_func_cache != NULL:
        del trace_level_func_cache

    trace_level_func_cache = new CodeLRUCache(size)
    if trace_level_func_cache == NULL:
        raise Exception("failed to create trace level func cache (size: {})".format(size))
