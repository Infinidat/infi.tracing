from cpython import Py_UNICODE
from cpython.ref cimport Py_INCREF, Py_XDECREF
from libcpp cimport bool

cdef extern from *:
    enum:
        true
        false

cdef extern from "Python.h":
    ctypedef struct PyTypeObject:
        const char* tp_name
        long tp_flags

    ctypedef struct PyObject:
        Py_ssize_t ob_refcnt
        PyTypeObject* ob_type

    ctypedef struct PyClassObject:
        PyObject* cl_bases
        PyObject* cl_dict
        PyObject* cl_name

    ctypedef struct PyFunctionObject:
        PyObject* func_code
        PyObject* func_globals
        PyObject* func_defaults
        PyObject* func_closure
        PyObject* func_doc
        PyObject* func_name
        PyObject* func_dict
        PyObject* func_weakreflist
        PyObject* func_module

    ctypedef struct PyHeapTypeObject:
        PyTypeObject ht_type
        PyObject* ht_name

    PyObject* Py_None
    PyObject* Py_False
    PyObject* Py_True

cdef extern from "pystate.h":
    ctypedef struct PyThreadState:
        long thread_id
        PyObject* exc_type
        PyObject* exc_value
        PyObject* exc_traceback

cdef extern from "frameobject.h":
    ctypedef struct PyCodeObject:
        int co_argcount
        int co_flags
        PyObject* co_names
        PyObject* co_varnames
        PyObject* co_filename
        PyObject* co_name

    ctypedef struct PyFrameObject:
        PyFrameObject* f_back
        PyCodeObject* f_code
        PyObject* f_globals
        PyThreadState* f_tstate
        PyObject* f_localsplus[1]
        PyObject* f_exc_type
        PyObject* f_exc_value
        PyObject* f_exc_traceback

    int PyFrame_GetLineNumber(PyFrameObject*)

    enum:
        CO_VARARGS
        CO_VARKEYWORDS

cdef extern from "Python.h":
    ctypedef long Py_ssize_t

    void Py_DECREF(PyObject*)
    PyTypeObject* Py_TYPE(PyObject*)
    PyObject* PyObject_Repr(PyObject* obj)

    # The following values are used for 'what' for tracefunc functions
    enum:
        PyTrace_CALL
        PyTrace_EXCEPTION
        PyTrace_LINE
        PyTrace_RETURN
        PyTrace_C_CALL
        PyTrace_C_EXCEPTION
        PyTrace_C_RETURN

        Py_TPFLAGS_HEAPTYPE

    ctypedef int (*Py_tracefunc)(PyObject*, PyFrameObject*, int, PyObject*)
    void PyEval_SetProfile(Py_tracefunc func, PyObject* arg)

    # int ops
    int PyInt_CheckExact(PyObject*)
    long PyInt_AS_LONG(PyObject*)

    # Long ops
    int PyLong_CheckExact(PyObject*)
    PyObject* _PyLong_Format(PyObject* aa, int base, int addL, int newstyle)

    # Float ops
    int PyFloat_CheckExact(PyObject*)
    PyObject* _PyFloat_FormatAdvanced(PyObject* obj, char* format_spec, Py_ssize_t format_spec_len)

    # String ops
    int PyString_CheckExact(PyObject*)
    int PyString_AsStringAndSize(PyObject* obj, char** s, Py_ssize_t* len)
    Py_ssize_t PyString_GET_SIZE(PyObject*)
    char* PyString_AS_STRING(PyObject*)
    char* PyString_AsString(PyObject*)
    PyObject* PyString_FromStringAndSize(char* str, Py_ssize_t size)
    PyObject* PyString_Repr(PyObject* obj, int smartquotes)

    # Unicode ops
    int PyUnicode_CheckExact(PyObject*)
    Py_ssize_t PyUnicode_GetSize(PyObject* unicode)
    Py_UNICODE* PyUnicode_AsUnicode(PyObject* unicode)
    PyObject* PyUnicode_FromUnicode(Py_UNICODE* unicode, Py_ssize_t size)

    # List ops
    int PyList_CheckExact(PyObject*)
    Py_ssize_t PyList_GET_SIZE(PyObject*)
    PyObject* PyList_GET_ITEM(PyObject*, int)

    # Tuple ops
    int PyTuple_CheckExact(PyObject*)
    Py_ssize_t PyTuple_GET_SIZE(PyObject*)
    PyObject* PyTuple_GET_ITEM(PyObject*, int)

    # Dict ops
    int PyDict_Check(PyObject*)
    int PyDict_CheckExact(PyObject*)
    Py_ssize_t PyDict_Size(PyObject*)
    int PyDict_Next(PyObject* p, Py_ssize_t* ppos, PyObject** pkey, PyObject** pvalue)

    # Function ops
    int PyFunction_Check(PyObject*)

    # Method ops
    int PyMethod_Check(PyObject*)
    PyObject* PyMethod_GET_FUNCTION(PyObject*)
    PyObject* PyMethod_GET_SELF(PyObject*)
    PyObject* PyMethod_GET_CLASS(PyObject*)

    # Type ops
    int PyType_Check(PyObject*)

cdef extern from "greenlet.h":
    ctypedef struct PyGreenlet
    void PyGreenlet_Import()
    PyGreenlet* PyGreenlet_GetCurrent()
    int PyGreenlet_ACTIVE(PyGreenlet* g)
    void** _PyGreenlet_API

cdef extern from "stdio.h":
    void printf(const char* format, ...) nogil
    int snprintf(char* str, int size, const char* format, ...) nogil
