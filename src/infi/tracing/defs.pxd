from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF, Py_XDECREF
from libcpp cimport bool

cdef extern from "pystate.h":
    ctypedef struct PyThreadState:
        long thread_id

cdef extern from "frameobject.h":
    ctypedef struct PyCodeObject:
        PyObject* co_name
        PyObject* co_filename
        int co_flags

    ctypedef struct PyFrameObject:
        PyFrameObject* f_back
        PyCodeObject* f_code
        PyObject* f_globals
        PyThreadState* f_tstate

    int PyFrame_GetLineNumber(PyFrameObject*)

cdef extern from "Python.h":
    char* PyString_AsString(PyObject*)

    ctypedef int (*Py_tracefunc)(PyObject*, PyFrameObject*, int, PyObject*)

    void PyEval_SetProfile(Py_tracefunc func, PyObject* arg)

    # The following values are used for 'what' for tracefunc functions
    enum:
        PyTrace_CALL
        PyTrace_EXCEPTION
        PyTrace_LINE
        PyTrace_RETURN
        PyTrace_C_CALL
        PyTrace_C_EXCEPTION
        PyTrace_C_RETURN

cdef extern from "greenlet.h":
    ctypedef struct PyGreenlet
    void PyGreenlet_Import()
    PyGreenlet* PyGreenlet_GetCurrent()
    int PyGreenlet_ACTIVE(PyGreenlet* g)
    void** _PyGreenlet_API

cdef extern from "stdlib.h":
    void printf(const char* format, ...) nogil
