from cpython.ref cimport PyObject
from libcpp cimport bool

cdef extern from "pthread.h":
    ctypedef int pthread_t
    pthread_t pthread_self() nogil

cdef extern from "frameobject.h":
    ctypedef struct PyCodeObject:
        PyObject* co_name
        int co_flags

    ctypedef struct PyFrameObject:
        PyCodeObject* f_code

    int PyFrame_GetLineNumber(PyFrameObject*)

cdef extern from "Python.h":
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

cdef extern from "stdlib.h":
    void printf(const char* format, ...)

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
