from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF, Py_XDECREF
from libcpp cimport bool

# FIXME: not needed anymore
# cdef extern from "pthread.h":
#     ctypedef long pthread_t
#     ctypedef long pthread_key_t
#     pthread_t pthread_self() nogil
#     long pthread_key_create(pthread_key_t* key, void (*destructor)(void*)) nogil
#     long pthread_getspecific(pthread_key_t key) nogil
#     void pthread_setspecific(pthread_key_t key, void* value) nogil

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
    int PyGreenlet_ACTIVE(PyGreenlet* g)
    void** _PyGreenlet_API

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

cdef extern from "<mutex>" namespace "std":
    cdef cppclass mutex:
        mutex()
        void lock() nogil
        void unlock() nogil
 
from libcpp.utility cimport pair
cdef extern from "<tr1/unordered_map>" namespace "std::tr1":
    cdef cppclass unordered_map[T, U]:
        cppclass iterator:
            pair[T, U]& operator*() nogil
            iterator operator++() nogil
            iterator operator--() nogil
            bint operator==(iterator) nogil
            bint operator!=(iterator) nogil
        unordered_map() nogil
        unordered_map(size_t) nogil
        unordered_map(unordered_map&) nogil
        U& operator[](T&) nogil
        # unordered_map& operator=(unordered_map&)
        U& at(T&) nogil
        iterator begin() nogil
        void clear() nogil
        size_t count(T&) nogil
        bint empty() nogil
        iterator end() nogil
        #pair[iterator, iterator] equal_range(T&) nogil
        iterator erase(iterator) nogil
        void erase(iterator, iterator) nogil
        size_t erase(T&) nogil
        iterator find(T&) nogil
        #pair[iterator, bint] insert(pair[T, U]) nogil
        #iterator insert(iterator, pair[T, U]) nogil
        void insert(input_iterator, input_iterator) nogil
        void insert(const U&) nogil
        size_t max_size() nogil
        void rehash(size_t) nogil
        size_t size() nogil
        void swap(unordered_map&) nogil
