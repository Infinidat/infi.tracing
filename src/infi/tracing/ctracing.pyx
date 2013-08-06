from cython.operator cimport dereference as deref, preincrement as inc, predecrement as dec
from defs cimport *

DEFAULT_FUNC_CACHE_SIZE = 10000

cdef enum:
    NO_TRACE              = 0
    NO_TRACE_NESTED       = 1
    TRACE_FUNC_NAME       = 2
    TRACE_FUNC_PRIMITIVES = 3
    TRACE_FUNC_REPR       = 4

    CLEANUP_CYCLES        = 10000  # Every 10k calls iterate over our greenlets and clean up greenlets that are done.

cdef extern from "thread_storage.h":
    cdef enum: NESTED_NO_TRACE_DISABLED "NESTED_NO_TRACE_DISABLED"

    cdef cppclass ThreadStorage:
        long depth
        long nested_no_trace_depth
        bool enabled
        ThreadStorage() nogil

cdef CodeLRUCache* trace_level_func_cache = NULL
cdef unordered_map[long, ThreadStorage] thread_storage_map = unordered_map[long, ThreadStorage](128)
cdef ThreadStorage empty_thread_depth
cdef long cleanup_counter = 0

cdef void cleanup_greenlet_thread_storage_map():
    """
    Iterate over our thread_storage_map that contains greenlet keys and remove greenlets that aren't active anymore.
    This function expects to run under GIL since it decrements references to the greenlets.
    """
    global thread_storage_map, cleanup_counter
    cdef unordered_map[long, ThreadStorage].iterator i
    cdef PyGreenlet* ptr

    i = thread_storage_map.begin()
    while i != thread_storage_map.end():
        ptr = <PyGreenlet*>deref(i).first
        if PyGreenlet_ACTIVE(ptr) == 0:
            # We use Py_XDECREF because Py_DECREF expects <object> and this leads to unnecessary inc refs and dec refs
            Py_XDECREF(<PyObject*>ptr)  
            i = thread_storage_map.erase(i)
        else:
            inc(i)

    cleanup_counter = 0

cdef inline ThreadStorage* find_or_create_thread_storage(PyGreenlet* greenlet) nogil:
    global thread_storage_map, empty_thread_depth
    if thread_storage_map.find(<long>greenlet) == thread_storage_map.end():
        # We have no record of this greenlet, so we need to make one and keep a live reference to it.
        with gil:
            Py_INCREF(<object>greenlet)
            thread_storage_map[<long>greenlet] = empty_thread_depth

    return &thread_storage_map[<long>greenlet]

cdef inline int find_trace_level_or_call_filter(PyFrameObject* frame, PyObject* filter_func) nogil:
    global trace_level_func_cache
    cdef int trace_level
    cdef CodeLRUCacheConstIterator code_found

    code_found = trace_level_func_cache.find(<long>frame.f_code)
    if code_found != trace_level_func_cache.end():
        trace_level = code_found.value()
    else:
        with gil:
            trace_level = int((<object>filter_func)(<object>frame.f_code))
        trace_level_func_cache.insert(<long>frame.f_code, trace_level)
    return trace_level

cdef inline PyGreenlet* current_greenlet_and_cleanup() with gil:
    """
    Find the current greenlet under GIL, increment our cleanup counter and if needed do the actual cleanup.
    We combined these two seemingly separate things (finding current greenlet and doing cleanups) since both require
    a GIL, so to optimize GIL locking we do both here.
    """
    global cleanup_counter
    cdef PyGreenlet* greenlet

    greenlet = PyGreenlet_GetCurrent()
    inc(cleanup_counter)
    if cleanup_counter > CLEANUP_CYCLES:
        cleanup_greenlet_thread_storage_map()
    return greenlet

cdef int greenlet_trace_func(PyObject* filter_func, PyFrameObject* frame, int what, PyObject* arg) nogil:
    cdef:
        PyGreenlet* greenlet
        int trace_level = NO_TRACE
        long depth, nested_no_trace_depth
        ThreadStorage* tstore

    greenlet = current_greenlet_and_cleanup()

    tstore = find_or_create_thread_storage(greenlet)
    if not tstore.enabled:
        return 0
        
    if what == PyTrace_CALL:
        inc(tstore.depth)
        depth = tstore.depth
    elif (what == PyTrace_EXCEPTION) or (what == PyTrace_RETURN):
        depth = tstore.depth
        dec(tstore.depth)
    else:
        # We don't trace through C calls, so we don't check the following:
        # PyTrace_C_CALL, PyTrace_C_EXCEPTION, PyTrace_C_RETURN
        return 0

    nested_no_trace_depth = tstore.nested_no_trace_depth

    if nested_no_trace_depth != NESTED_NO_TRACE_DISABLED:
        if nested_no_trace_depth < depth:
            return 0
        else:
            tstore.nested_no_trace_depth = NESTED_NO_TRACE_DISABLED

    trace_level = find_trace_level_or_call_filter(frame, filter_func)

    if trace_level == NO_TRACE:
        return 0
    elif trace_level == NO_TRACE_NESTED:
        tstore.nested_no_trace_depth = depth
        return 0

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

    return 0


def ctracing_set_profile(filter_func):
    global trace_level_func_cache, _PyGreenlet_API

    cdef ThreadStorage* tstore

    if filter_func is None:
        raise ValueError("filter_func cannot be None")

    PyGreenlet_Import()
    if trace_level_func_cache == NULL:
        ctracing_set_func_cache_size(DEFAULT_FUNC_CACHE_SIZE)

    if _PyGreenlet_API != NULL:
        tstore = find_or_create_thread_storage(PyGreenlet_GetCurrent())
        if tstore.depth == -1:
            # First time we're setting profile on this thread, so we need to adjust the depth so it'll include this call
            # (ctracing_set_profile).
            inc(tstore.depth)
        PyEval_SetProfile(greenlet_trace_func, <PyObject*>filter_func)
    else:
        raise ValueError("tracing only supported with greenlets for now")


def ctracing_set_func_cache_size(size):
    global trace_level_func_cache
    assert size >= 0

    if trace_level_func_cache != NULL:
        del trace_level_func_cache

    trace_level_func_cache = new CodeLRUCache(size)
    if trace_level_func_cache == NULL:
        raise Exception("failed to create trace level func cache (size: {})".format(size))

def suspend():
    cdef ThreadStorage* tstore = find_or_create_thread_storage(PyGreenlet_GetCurrent())
    tstore.enabled = False

def resume():
    cdef ThreadStorage* tstore = find_or_create_thread_storage(PyGreenlet_GetCurrent())
    tstore.enabled = True
