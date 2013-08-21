from cython.operator cimport dereference as deref, preincrement as inc, predecrement as dec
from defs cimport *

DEFAULT_FUNC_CACHE_SIZE = 10000

cdef enum:
    NO_TRACE              = 0
    NO_TRACE_NESTED       = 1
    TRACE_FUNC_NAME       = 2
    TRACE_FUNC_PRIMITIVES = 3
    TRACE_FUNC_REPR       = 4

from thread_storage cimport ThreadStorage, GreenletStorage, NO_TRACE_FROM_DEPTH_DISABLED, get_thread_storage
from trace_dump cimport TraceDump, FileTraceDump, SyslogTraceDump
from libc.stdio cimport FILE, fopen, fprintf, fclose, fwrite, stdout

include "log.pyx"
include "trace_level_func_cache.pyx"

cdef enum:
    TRACE_NONE   = 0
    TRACE_FILE   = 1
    TRACE_SYSLOG = 2

cdef int trace_output = TRACE_NONE

cdef FILE* trace_file_handle = NULL


cdef inline long calc_new_greenlet_depth(PyFrameObject* frame) nogil:
    cdef long depth = 0
    while frame.f_back != NULL:
        inc(depth)
        frame = frame.f_back
    return depth


cdef inline GreenletStorage* get_gstore_on_call(ThreadStorage* tstore, PyFrameObject* frame) nogil:
    cdef:
        long gid
        GreenletStorage* gstore

    # Easy route: if we're in the same greenlet we may have the greenlet ID cached.
    if (tstore.last_frame != 0) and (tstore.last_frame == <long>frame.f_back):
        gid = tstore.last_gid
    else:
        with gil:
            greenlet = PyGreenlet_GetCurrent()
        gid = <long>greenlet

    tstore.last_gid = gid
    tstore.last_frame = <long>frame

    gstore = tstore.find_gstorage(gid)
    if gstore == NULL:
        gstore = tstore.new_gstorage(gid)
        gstore.depth = calc_new_greenlet_depth(frame)

    return gstore


cdef inline GreenletStorage* get_gstore_on_return(ThreadStorage* tstore, PyFrameObject* frame) nogil:
    cdef:
        long gid
        GreenletStorage* gstore

    # Easy route: if we're in the same greenlet we may have the greenlet ID cached.
    if (tstore.last_frame != 0) and (tstore.last_frame == <long>frame):
        gid = tstore.last_gid
    else:
        with gil:
            greenlet = PyGreenlet_GetCurrent()
        gid = <long>greenlet

    tstore.last_gid = gid
    tstore.last_frame = <long>frame.f_back

    gstore = tstore.find_gstorage(gid)
    if gstore == NULL:
        gstore = tstore.new_gstorage(gid)
        gstore.depth = calc_new_greenlet_depth(frame)

    return gstore


cdef int greenlet_trace_func(PyObject* filter_func, PyFrameObject* frame, int what, PyObject* arg) nogil:
    global cleanup_counter
    cdef:
        int trace_level = NO_TRACE
        long gid, depth, no_trace_from_depth
        ThreadStorage* tstore
        GreenletStorage* gstore = NULL

    tstore = get_thread_storage()

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
        log_call(trace_level, gid, depth, frame, arg)
    else:
        log_return(trace_level, gid, depth, frame, arg)

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


def ctracing_set_output_to_syslog(ident, facility):
    global trace_output
    cdef:
        const char* ident_str = ident
        int facility_int = facility
    openlog(ident_str, LOG_NDELAY, facility_int)
    trace_output = TRACE_SYSLOG


def ctracing_set_output_to_file(path):
    global trace_file_handle, trace_output
    trace_file_handle = fopen(path, "wb")
    if trace_file_handle == NULL:
        raise ValueError("failed to open trace file {} for writing".format(path))
    trace_output = TRACE_FILE


def ctracing_set_output_to_stdout():
    global trace_file_handle, trace_output
    trace_file_handle == stdout
    trace_output = TRACE_FILE


cdef TraceDump* trace_dump = NULL
def ctracing_start_trace_dump():
    global trace_dump, trace_output
    if trace_dump != NULL:
        raise ValueError("trace dump already started")

    if trace_output == TRACE_SYSLOG:
        trace_dump = new SyslogTraceDump()
    elif trace_output == TRACE_FILE:
        trace_dump = new FileTraceDump(trace_file_handle)
    elif trace_output == TRACE_NONE:
        pass

    if trace_dump != NULL:
        trace_dump.start()
    
def ctracing_stop_trace_dump():
    global trace_dump
    if trace_dump != NULL:
        trace_dump.stop()
        del trace_dump
        trace_dump = NULL


def suspend():
    cdef ThreadStorage* tstore = get_thread_storage()
    dec(tstore.enabled)


def resume():
    cdef ThreadStorage* tstore = get_thread_storage()
    if tstore.enabled <= 0:
        inc(tstore.enabled)
