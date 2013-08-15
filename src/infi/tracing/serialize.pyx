from defs cimport *

cdef enum:
    # Maximum string/unicode character length to serialize. If a string/unicode is longer, it will get truncated.
    MAX_STR_LEN       = 64
    # Maximum element byte length for each element in a list
    MAX_LIST_ELEM_LEN = 64
    # Number of items to serialize in a list before truncating
    MAX_LIST_ELEMS    = 4
    # Number of dict items to serialize before truncating
    MAX_DICT_ELEMS    = 4
    # Maximum serialized key length in a dict
    MAX_DICT_KEY_LEN  = 16
    # Maximum serialized value in a dict
    MAX_DICT_VAL_LEN  = 64


cdef inline int max(int a, int b) nogil:
    return a if a > b else b


cdef inline int min(int a, int b) nogil:
    return a if a < b else b


cdef inline int int_repr(PyObject* ptr, char* output, int maxlen):
    # FIXME: if truncated we should warn about this
    cdef int n
    n = snprintf(output, maxlen, "%ld", PyInt_AS_LONG(ptr))
    if n == maxlen:
        return 0
    return n


cdef inline int long_repr(PyObject* ptr, char* output, int maxlen):
    cdef:
        PyObject* s
        int n

    # FIXME check for NULL
    s = _PyLong_Format(ptr, 10, 0, 0)
    if PyString_GET_SIZE(s) <= maxlen:
        n = snprintf(output, maxlen, "%s", PyString_AsString(s))
    else:
        n = 0
    Py_DECREF(s)
    return n


cdef inline int float_repr(PyObject* ptr, char* output, int maxlen):
    cdef:
        PyObject* s
        int n

    # FIXME check for NULL
    s = _PyFloat_FormatAdvanced(ptr, "g", 1)
    if PyString_GET_SIZE(s) <= maxlen + 1:
        n = snprintf(output, maxlen, "%sf", PyString_AsString(s))
    else:
        n = 0
    Py_DECREF(s)
    return n


cdef inline int init_trunc_len_str(char* buffer, int buffer_len, int len):
    buffer[buffer_len - 1] = '\0'
    return snprintf(buffer, buffer_len - 1, "... <len=%d>", len)


cdef inline int str_or_unicode_repr(bool is_unicode, PyObject* ptr, char* output, int maxlen):
    cdef:
        char* str_ptr = NULL
        Py_ssize_t str_len = 0
        Py_ssize_t repr_len = 0
        PyObject* tmp_ptr = NULL
        PyObject* repr_ptr = NULL
        int n = 0
        int truncated_len = 0
        char truncated_buffer[64]
        bool truncated = false

    str_len = PyUnicode_GetSize(ptr) if is_unicode else PyString_GET_SIZE(ptr)

    # We check if the string before repr is longer than our target buffer. We do this so we won't create a repr for
    # a very long string only to truncate it a few code lines later...
    truncated = str_len > MAX_STR_LEN
    if truncated:
        # FIXME check for NULL
        if is_unicode:
            tmp_ptr = PyUnicode_FromUnicode(PyUnicode_AsUnicode(ptr), MAX_STR_LEN)
            repr_ptr = PyObject_Repr(tmp_ptr)
        else:
            tmp_ptr = PyString_FromStringAndSize(PyString_AS_STRING(ptr), MAX_STR_LEN)
            repr_ptr = PyString_Repr(tmp_ptr, 0)
        Py_DECREF(tmp_ptr)
    else:
        # FIXME check for NULL
        repr_ptr = PyObject_Repr(ptr) if is_unicode else PyString_Repr(ptr, 0)

    PyString_AsStringAndSize(repr_ptr, &str_ptr, &repr_len)

    if truncated or (repr_len + 1) > maxlen:  # +1 is for null in snprintf
        truncated = true
        truncated_len = init_trunc_len_str(truncated_buffer, 64, str_len)
    else:
        truncated_buffer[0] = '\0'

    if (maxlen - truncated_len - 1) < repr_len:  # -1 is for snprintf's null at the end
        # We need to minimize our repr even still since it doesn't have enough room.
        repr_len = (maxlen - truncated_len) - 2  # -1 is for the extra ' we put and snprintf's null at the end
        if repr_len > 0:
            n = snprintf(output, maxlen, "%.*s'%s", repr_len, str_ptr, truncated_buffer)
        else:
            # FIXME: real problem here. Our caller haven't allocated enough space to write even "''... <len=xxxx>"
            #        (w/o the double-quotes). This ain't nice.
            n = 0
    else:
        n = snprintf(output, maxlen, "%s%s", str_ptr, truncated_buffer)

    Py_DECREF(repr_ptr)

    return n

# This prevents cython from trying to convert the strings to Python and back in list_or_tuple_repr
cdef const char* list_open_paren = "["
cdef const char* list_close_paren = "]"
cdef const char* tuple_open_paren = "("
cdef const char* tuple_close_paren = ")"

cdef inline int list_or_tuple_repr(bool is_list, PyObject* ptr, char* output, int maxlen):
    cdef:
        Py_ssize_t list_len
        int i = 0
        int bytes_written
        int last_bytes_written = 0
        int elem_len, elem_written
        bool truncated = false
        int truncated_len = 0
        char truncated_buffer[64]
        const char* open_paren
        const char* close_paren

    if is_list:
        open_paren, close_paren = list_open_paren, list_close_paren
    else:
        open_paren, close_paren = tuple_open_paren, tuple_close_paren

    list_len = PyList_GET_SIZE(ptr) if is_list else PyTuple_GET_SIZE(ptr)

    truncated_len = init_trunc_len_str(truncated_buffer, 64, list_len)

    if truncated_len + 3 > maxlen:  # +3 is for [] and snprintf's null at the end
        # FIXME: real problem here. Our caller haven't allocated enough space to write even "[]... <len=xxxx>"
        #        (w/o the double-quotes). This ain't nice.
        return 0 

    bytes_written = snprintf(output, maxlen, open_paren)

    for i in range(min(list_len, MAX_LIST_ELEMS)):
        last_bytes_written = bytes_written

        if i != 0:
            bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, ",")

        if (maxlen - bytes_written) <= truncated_len + 2:  # +2 is the closing parenthesis and snprintf's null
            truncated = true
            break

        elem_len = min((maxlen - bytes_written) - (truncated_len + 2), MAX_LIST_ELEM_LEN)
        elem_written = fast_repr(PyList_GET_ITEM(ptr, i) if is_list else PyTuple_GET_ITEM(ptr, i), 
                                 &output[bytes_written], elem_len)
        if elem_written == 0:
            bytes_written = last_bytes_written
            truncated = true
            break
        bytes_written += elem_written


    bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, close_paren)

    if (i + 1) < list_len or truncated:
        if maxlen - bytes_written < truncated_len:
            # Not enough room for "...<len=xxx>", so we have to overwrite last element.
            bytes_written = last_bytes_written + snprintf(&output[last_bytes_written], maxlen - last_bytes_written,
                "%s%s", close_paren, truncated_buffer)
        else:
            bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, "%s", truncated_buffer)

    return bytes_written


cdef int dict_repr(PyObject* ptr, char* output, int maxlen) with gil:
    cdef:
        Py_ssize_t dict_len, prev_pos
        int bytes_written
        int last_bytes_written = 0
        int elem_len, elem_written
        int i = 0
        PyObject* key_ptr = NULL
        PyObject* val_ptr = NULL
        bool truncated = false
        int truncated_len = 0
        char truncated_buffer[64]

    dict_len = PyDict_Size(ptr)

    truncated_len = init_trunc_len_str(truncated_buffer, 64, dict_len)

    if truncated_len + 3 > maxlen:  # +3 is for [] and snprintf's null at the end
        # FIXME: real problem here. Our caller haven't allocated enough space to write even "{}... <len=xxxx>"
        #        (w/o the double-quotes). This ain't nice.
        return 0

    prev_pos = 0
    bytes_written = snprintf(output, maxlen, "{")
    for i in range(min(dict_len, MAX_DICT_ELEMS)):
        if PyDict_Next(ptr, &prev_pos, &key_ptr, &val_ptr) == 0:
            break

        if (maxlen - bytes_written) <= truncated_len + 2:  # +2 is the closing parenthesis and snprintf's null
            truncated = true
            break

        last_bytes_written = bytes_written
        if i > 0:
            bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, ",")
        elem_len = min(maxlen - bytes_written - 2, MAX_DICT_KEY_LEN)
        elem_written = fast_repr(key_ptr, &output[bytes_written], elem_len)
        if elem_written == 0:
            bytes_written = last_bytes_written
            truncated = true
            break
        bytes_written += elem_written
        elem_written = snprintf(&output[bytes_written], maxlen - bytes_written, ":")
        if elem_written == 0:
            bytes_written = last_bytes_written
            truncated = true
            break
        bytes_written += elem_written
        elem_len = min(maxlen - bytes_written - 2, MAX_DICT_VAL_LEN)
        elem_written = fast_repr(val_ptr, &output[bytes_written], elem_len)
        if elem_written == 0:
            bytes_written = last_bytes_written
            truncated = true
            break
        bytes_written += elem_written
    bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, "}")
    if (i + 1) < dict_len or truncated:
        if maxlen - bytes_written - 1 < truncated_len:
            # Not enough room for "...<len=xxx>", so we have to overwrite last element.
            bytes_written = last_bytes_written + snprintf(&output[last_bytes_written], maxlen - last_bytes_written,
                                                          "}%s", truncated_buffer)
        else:
            bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, "%s", truncated_buffer)
    return bytes_written


cdef inline int write_function_name(PyFunctionObject* func_ptr, char* output, int maxlen):
    if func_ptr == NULL:
        return snprintf(output, maxlen, "unknown")
    return snprintf(output, maxlen, "%s", PyString_AS_STRING(func_ptr.func_name))


cdef inline int write_type_name(PyTypeObject* ptr, char* output, int maxlen):
    # Taken from Python's typeobject.c
    if (ptr.tp_flags & Py_TPFLAGS_HEAPTYPE) != 0:
        return snprintf(output, maxlen, "%s", PyString_AS_STRING((<PyHeapTypeObject*> ptr).ht_name))
    else:
        return snprintf(output, maxlen, "%s", ptr.tp_name)


cdef inline int function_repr(PyFunctionObject* ptr, char* output, int maxlen):
    cdef int bytes_written
    bytes_written = snprintf(output, maxlen, "<func ")
    bytes_written += write_function_name(ptr, &output[bytes_written], maxlen - bytes_written)
    bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, " 0x%lx>", ptr)
    return bytes_written


cdef inline int method_repr(PyObject* ptr, char* output, int maxlen):
    cdef:
        PyObject* func
        PyObject* self
        PyObject* klass
        int bytes_written = 0

    func = PyMethod_GET_FUNCTION(ptr)
    self = PyMethod_GET_SELF(ptr)
    klass = PyMethod_GET_CLASS(ptr)

    bytes_written += snprintf(output, maxlen, "<method ")
    bytes_written += write_function_name(<PyFunctionObject*>func, &output[bytes_written], maxlen - bytes_written)
    if klass != NULL and PyType_Check(klass):
        bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, " cls ")
        bytes_written += write_type_name(<PyTypeObject*>klass, &output[bytes_written], maxlen - bytes_written)
    if self != NULL:
        bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, " obj 0x%lx", <long> self)
    bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, ">")
    return bytes_written


cdef inline int type_repr(PyObject* ptr, char* output, int maxlen):
    cdef int bytes_written

    bytes_written = snprintf(output, maxlen, "<type ")
    bytes_written += write_type_name(<PyTypeObject*>ptr, &output[bytes_written], maxlen - bytes_written)
    bytes_written += snprintf(&output[bytes_written], maxlen - bytes_written, ">")
    return bytes_written

cdef inline int py_repr(PyObject* ptr, char* output, int maxlen):
    cdef:
        PyObject* repr_obj
        Py_ssize_t repr_len
        char* repr_ptr
        int n

    # FIXME check NULL here
    repr_obj = PyObject_Repr(ptr)
    PyString_AsStringAndSize(repr_obj, &repr_ptr, &repr_len)
    n = snprintf(output, maxlen, "%.*s", repr_len, repr_ptr)
    Py_DECREF(repr_obj)
    return n


cdef inline int obj_repr(PyObject* ptr, char* output, int maxlen):
    return snprintf(output, maxlen, "<%s 0x%lx>", ptr.ob_type.tp_name, <long> ptr)


cdef inline int fast_repr(PyObject* ptr, char* output, int maxlen) with gil:
    if PyInt_CheckExact(ptr):
        return int_repr(ptr, output, maxlen)
    elif PyLong_CheckExact(ptr):
        return long_repr(ptr, output, maxlen)
    elif PyFloat_CheckExact(ptr):
        return float_repr(ptr, output, maxlen)
    elif PyString_CheckExact(ptr):
        return str_or_unicode_repr(false, ptr, output, maxlen)
    elif PyUnicode_CheckExact(ptr):
        return str_or_unicode_repr(true, ptr, output, maxlen)
    elif PyDict_CheckExact(ptr):
        return dict_repr(ptr, output, maxlen)
    elif PyList_CheckExact(ptr):
        return list_or_tuple_repr(true, ptr, output, maxlen)
    elif PyTuple_CheckExact(ptr):
        return list_or_tuple_repr(false, ptr, output, maxlen)
    elif ptr == Py_None:
        return snprintf(output, maxlen, "None")
    elif ptr == Py_True:
        return snprintf(output, maxlen, "True")
    elif ptr == Py_False:
        return snprintf(output, maxlen, "False")
    elif PyFunction_Check(ptr):
        return function_repr(<PyFunctionObject*>ptr, output, maxlen)
    elif PyMethod_Check(ptr):
        return method_repr(ptr, output, maxlen)
    elif PyType_Check(ptr):
        return type_repr(ptr, output, maxlen)
    else:
        return obj_repr(ptr, output, maxlen)
