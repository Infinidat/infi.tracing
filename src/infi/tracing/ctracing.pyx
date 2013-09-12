from cython.operator cimport dereference as deref, preincrement as inc, predecrement as dec

from defs cimport *
from thread_storage cimport (ThreadStorage, GreenletStorage, NO_TRACE_FROM_DEPTH_DISABLED, 
                             init_thread_storage_once, get_thread_storage)
from trace_message_ring_buffer cimport TraceMessageRingBuffer
from os import getpid

DEFAULT_FUNC_CACHE_SIZE = 10000

cdef enum:
    NO_TRACE              = 0
    NO_TRACE_NESTED       = 1
    TRACE_FUNC_NAME       = 2
    TRACE_FUNC_PRIMITIVES = 3
    TRACE_FUNC_REPR       = 4


cdef unsigned long pid = -1
cdef unsigned long gid_hit = 0, gid_miss = 0
cdef unsigned long gstore_hit = 0, gstore_miss = 0

cdef TraceMessageRingBuffer trace_message_ring_buffer

include "trace_level_func_cache.pyx"
include "ctracing_log.pyx"
include "ctracing_trace_dump.pyx"

cdef inline long calc_new_greenlet_depth(PyFrameObject* frame) nogil:
    cdef long depth = 0
    while frame.f_back != NULL:
        inc(depth)
        frame = frame.f_back
    return depth

# Apparently when adding a GIL context to a function, Cython creates on the function's return that adds to the runtime 
# cost even if the GIL context wasn't reached inside the function.
# That's why we had to create this function, so GIL won't get called if this isn't called.
cdef inline long get_current_gid() with gil:
    cdef PyGreenlet* g = PyGreenlet_GetCurrent()
    Py_DECREF(<PyObject*> g)
    return <long> g

cdef inline GreenletStorage* get_gstore_on_call(ThreadStorage* tstore, PyFrameObject* frame) nogil:
    global gid_hit, gid_miss, gstore_hit, gstore_miss
    cdef:
        long gid
        GreenletStorage* gstore

    # Easy route: if we're in the same greenlet we may have the greenlet ID cached.
    if (tstore.last_frame != 0) and (tstore.last_frame == <long>frame.f_back):
        gid = tstore.last_gid
        gstore = tstore.last_gstorage
        inc(gid_hit)
    else:
        inc(gid_miss)
        gid = get_current_gid()
        gstore = NULL

    tstore.last_gid = gid
    tstore.last_frame = <long>frame

    if gstore == NULL:
        inc(gstore_miss)
        gstore = tstore.find_gstorage(gid)
        if gstore == NULL:
            gstore = tstore.new_gstorage(gid)
            gstore.depth = calc_new_greenlet_depth(frame)
        tstore.last_gstorage = gstore
    else:
        inc(gstore_hit)

    return gstore


cdef inline GreenletStorage* get_gstore_on_return(ThreadStorage* tstore, PyFrameObject* frame) nogil:
    global gid_hit, gid_miss, gstore_hit, gstore_miss
    cdef:
        long gid
        GreenletStorage* gstore

    # Easy route: if we're in the same greenlet we may have the greenlet ID cached.
    if (tstore.last_frame != 0) and (tstore.last_frame == <long>frame):
        gid = tstore.last_gid
        gstore = tstore.last_gstorage
        inc(gid_hit)
    else:
        inc(gid_miss)
        gid = get_current_gid()
        gstore = NULL

    tstore.last_gid = gid
    tstore.last_frame = <long>frame.f_back

    if gstore == NULL:
        inc(gstore_miss)
        gstore = tstore.find_gstorage(gid)
        if gstore == NULL:
            gstore = tstore.new_gstorage(gid)
            gstore.depth = calc_new_greenlet_depth(frame)
        tstore.last_gstorage = gstore
    else:
        inc(gstore_hit)

    return gstore


cdef int greenlet_trace_func(PyObject* filter_func, PyFrameObject* frame, int what, PyObject* arg) nogil:
    cdef:
        int trace_level = NO_TRACE
        unsigned long tid
        long gid, depth, no_trace_from_depth
        ThreadStorage* tstore
        GreenletStorage* gstore = NULL

    tstore = get_thread_storage()
    tid = tstore.id

    if what == PyTrace_CALL:
        gstore = get_gstore_on_call(tstore, frame)
        inc(gstore.depth)
        depth = gstore.depth
        no_trace_from_depth = gstore.no_trace_from_depth
        gid = gstore.gid
    elif what == PyTrace_RETURN:
        gstore = get_gstore_on_return(tstore, frame)
        depth = gstore.depth
        no_trace_from_depth = gstore.no_trace_from_depth
        gid = gstore.gid

        if frame.f_back == NULL:
            tstore.del_gstorage(gstore.gid)
            gstore = NULL
        else:
            dec(gstore.depth)
    else:
        # We don't trace through C calls, so we don't check the following:
        # PyTrace_C_CALL, PyTrace_C_EXCEPTION, PyTrace_C_RETURN
        # Also, PyTrace_EXCEPTION cannot happen with a profile function.
        return 0

    if tstore.enabled <= 0:
        return 0

    if no_trace_from_depth != NO_TRACE_FROM_DEPTH_DISABLED:
        if no_trace_from_depth < depth:
            return 0
        elif gstore != NULL:
            gstore.no_trace_from_depth = NO_TRACE_FROM_DEPTH_DISABLED

    trace_level = find_trace_level_or_call_filter(frame, filter_func)

    if trace_level == NO_TRACE:
        return 0
    elif trace_level == NO_TRACE_NESTED:
        if gstore != NULL:
            gstore.no_trace_from_depth = depth
        return 0

    if what == PyTrace_CALL:
        log_call(trace_level, tid, gid, depth, frame, arg)
    else:
        log_return(trace_level, tid, gid, depth, frame, arg)

    return 0


def ctracing_set_profile(filter_func):
    global pid, trace_level_func_cache, _PyGreenlet_API

    init_thread_storage_once()
    pid = <long> getpid()  # We set this once per process so we won't call this method on every trace.

    cdef ThreadStorage* tstore

    if filter_func is None:
        raise ValueError("filter_func cannot be None")

    PyGreenlet_Import()
    if trace_level_func_cache == NULL:
        ctracing_set_func_cache_size(DEFAULT_FUNC_CACHE_SIZE)

    if _PyGreenlet_API != NULL:
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


def ctracing_print_stats():
    global gid_hit, gid_miss, gstore_hit, gstore_miss, func_cache_hit, func_cache_miss
    print("gid hits: {}, misses: {}".format(gid_hit, gid_miss))
    print("gstore hits: {}, misses: {}".format(gstore_hit, gstore_miss))
    print("func cache hits: {}, misses: {}".format(func_cache_hit, func_cache_miss))
    print("overflow message counter: {}".format(trace_message_ring_buffer.get_overflow_counter()))
    print("spinlock counters: consumer {} / producer {}".format(
        trace_message_ring_buffer.get_spinlock_consumer_wait_counter(),
        trace_message_ring_buffer.get_spinlock_producer_wait_counter()))


def suspend():
    cdef ThreadStorage* tstore = get_thread_storage()
    dec(tstore.enabled)


def resume():
    cdef ThreadStorage* tstore = get_thread_storage()
    if tstore.enabled <= 0:
        inc(tstore.enabled)
