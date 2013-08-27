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
    MAX_DICT_KEY_LEN  = 32
    # Maximum serialized value in a dict
    MAX_DICT_VAL_LEN  = 64


cdef inline int max(int a, int b) nogil:
    return a if a > b else b


cdef inline int min(int a, int b) nogil:
    return a if a < b else b


cdef inline bool int_repr(PyObject* ptr, TraceMessage* output):
    return output.printf("%ld", PyInt_AS_LONG(ptr))


cdef inline bool long_repr(PyObject* ptr, TraceMessage* output):
    # FIXME check for NULL
    cdef PyObject* s = _PyLong_Format(ptr, 10, 0, 0)
    try:
        if PyString_GET_SIZE(s) <= output.avail_size():
            return output.write(PyString_AsString(s))
        else:
            return false
    finally:
        Py_DECREF(s)


cdef inline bool float_repr(PyObject* ptr, TraceMessage* output):
    # FIXME check for NULL
    cdef PyObject* s = _PyFloat_FormatAdvanced(ptr, "g", 1)
    try:
        if PyString_GET_SIZE(s) + 1 <= output.avail_size():
            output.write(PyString_AsString(s))
            output.write("f")
            return true
        else:
            return false
    finally:
        Py_DECREF(s)


cdef inline int init_trunc_len_str(char* buffer, int buffer_len, int len):
    buffer[buffer_len - 1] = '\0'
    return snprintf(buffer, buffer_len - 1, "... <len=%d>", len)


cdef inline bool str_or_unicode_repr(bool is_unicode, PyObject* ptr, TraceMessage* output):
    cdef:
        char* str_ptr = NULL
        Py_ssize_t str_len = 0
        Py_ssize_t repr_len = 0
        PyObject* tmp_ptr = NULL
        PyObject* repr_ptr = NULL
        int truncated_len = 0
        char truncated_buffer[64]
        bool truncated = false

    str_len = PyUnicode_GetSize(ptr) if is_unicode else PyString_GET_SIZE(ptr)

    # We check if the string before repr'ing is longer than our target buffer. We do this so we won't waste time/mem
    # to create a repr for a very long string only to truncate it a few code lines later.
    truncated = str_len > MAX_STR_LEN
    if truncated:
        # FIXME check for NULL on all the xxx_Repr calls.
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

    try:
        PyString_AsStringAndSize(repr_ptr, &str_ptr, &repr_len)

        if truncated or (repr_len + 1) > output.avail_size():  # +1 is for null in snprintf
            truncated = true
            truncated_len = init_trunc_len_str(truncated_buffer, 64, str_len)
        else:
            truncated_buffer[0] = '\0'

        if (repr_len + truncated_len + 1) > output.avail_size():  # +1 is for snprintf's null at the end
            # We need to minimize our repr even still since it doesn't have enough room.
            repr_len = output.avail_size() - truncated_len - 2  # -2 is for the extra ' we put and snprintf's null
            if repr_len > 0:
                return output.printf("%.*s'%s", repr_len, str_ptr, truncated_buffer)
            else:
                # FIXME: real problem here. Our caller haven't allocated enough space to write even "''... <len=xxxx>"
                #        (w/o the double-quotes). This ain't nice.
                return false
        else:
            return output.printf("%s%s", str_ptr, truncated_buffer)
    finally:
        Py_DECREF(repr_ptr)


# This hack prevents Cython from trying to convert the strings to Python and back in list_or_tuple_repr
cdef const char* list_open_paren = "["
cdef const char* list_close_paren = "]"
cdef const char* tuple_open_paren = "("
cdef const char* tuple_close_paren = ")"

cdef inline bool list_or_tuple_repr(bool is_list, PyObject* ptr, TraceMessage* output):
    cdef:
        Py_ssize_t list_len
        int i = 0
        int ofs_with_spare_for_truncated_len = 0, last_limit
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

    if truncated_len + 3 > output.avail_size():  # +3 is for [] and snprintf's null at the end
        # FIXME: real problem here. Our caller haven't allocated enough space to write even "[]... <len=xxxx>"
        #        (w/o the double-quotes). This ain't nice.
        return false

    output.write(open_paren)

    for i in range(min(list_len, MAX_LIST_ELEMS)):
        if output.avail_size() >= truncated_len + 2:  # +2: enough room for closing parenthesis, sprintf's null
            ofs_with_spare_for_truncated_len = output.write_offset()

        last_limit = output.limit(MAX_LIST_ELEM_LEN)
        try:
            if i > 0:
                if not output.write(","):
                    truncated = true
                    break

            if not fast_repr(PyList_GET_ITEM(ptr, i) if is_list else PyTuple_GET_ITEM(ptr, i), output):
                truncated = true
                break
        finally:
            output.unlimit(last_limit)

    if not output.write(close_paren):
        truncated = true

    if (i + 1) < list_len or truncated:
        if output.avail_size() < truncated_len:
            # Not enough room for "...<len=xxx>", so we have to overwrite some elements.
            output.rewind(ofs_with_spare_for_truncated_len)
            output.printf("%s%s", close_paren, truncated_buffer)
        else:
            output.write(truncated_buffer)

    return true


cdef int dict_repr(PyObject* ptr, TraceMessage* output):
    cdef:
        Py_ssize_t dict_len, prev_pos
        int ofs_with_spare_for_truncated_len = 0
        int last_limit
        int i = 0
        PyObject* key_ptr = NULL
        PyObject* val_ptr = NULL
        bool truncated = false
        int truncated_len
        char truncated_buffer[64]

    dict_len = PyDict_Size(ptr)

    truncated_len = init_trunc_len_str(truncated_buffer, 64, dict_len)

    if truncated_len + 3 > output.avail_size():  # +3 is for [] and snprintf's null at the end
        # FIXME: real problem here. Our caller haven't allocated enough space to write even "{}... <len=xxxx>"
        #        (w/o the double-quotes). This ain't nice.
        return false

    prev_pos = 0
    output.write("{")
    for i in range(min(dict_len, MAX_DICT_ELEMS)):
        if PyDict_Next(ptr, &prev_pos, &key_ptr, &val_ptr) == 0:
            break

        if output.avail_size() >= truncated_len + 2: # +2 is the closing parenthesis and snprintf's null
            ofs_with_spare_for_truncated_len = output.write_offset()

        if i > 0:
            if not output.write(","):
                truncated = true
                break

        last_limit = output.limit(MAX_DICT_KEY_LEN)
        try:
            if not fast_repr(key_ptr, output):
                truncated = true
                break
        finally:
            output.unlimit(last_limit)

        if not output.write(":"):
            truncated = true
            break

        last_limit = output.limit(MAX_DICT_VAL_LEN)
        try:
            if not fast_repr(val_ptr, output):
                truncated = true
                break
        finally:
            output.unlimit(last_limit)

    if not output.write("}"):
        truncated = true

    if (i + 1) < dict_len or truncated:
        if output.avail_size() < truncated_len:
            # Not enough room for "...<len=xxx>", so we have to overwrite some elements.
            output.rewind(ofs_with_spare_for_truncated_len)
            output.printf("}%s", truncated_buffer)
        else:
            output.write(truncated_buffer)
    return true


cdef inline bool write_function_name(PyFunctionObject* func_ptr, TraceMessage* output):
    if func_ptr == NULL:
        return output.write("unknown")
    return output.write(PyString_AS_STRING(func_ptr.func_name))


cdef inline bool write_type_name(PyTypeObject* ptr, TraceMessage* output):
    # Taken from Python's typeobject.c
    if (ptr.tp_flags & Py_TPFLAGS_HEAPTYPE) != 0:
        return output.write(PyString_AS_STRING((<PyHeapTypeObject*> ptr).ht_name))
    else:
        return output.write(ptr.tp_name)


cdef inline bool function_repr(PyFunctionObject* ptr, TraceMessage* output):
    cdef int prev_pos
    if output.avail_size() < 9:  # enough room for <func ?>
        return false

    output.write("<func ")
    prev_pos = output.write_offset()
    if not write_function_name(ptr, output):
        output.rewind(prev_pos)
        output.write("?>")
    else:
        output.write(">")

    return true


cdef inline bool method_repr(PyObject* ptr, TraceMessage* output):
    cdef:
        PyObject* func
        PyObject* self
        PyObject* klass
        int prev_pos = 0
        bool success

    if output.avail_size() < 11:  # enough room for <method ?>
        return false

    func = PyMethod_GET_FUNCTION(ptr)
    self = PyMethod_GET_SELF(ptr)
    klass = PyMethod_GET_CLASS(ptr)


    output.write("<meth ")
    prev_pos = output.write_offset()

    success = write_function_name(<PyFunctionObject*>func, output)
    if success:
        if klass != NULL and PyType_Check(klass):
            success = output.write(" cls ")
            if success:
                success = write_type_name(<PyTypeObject*>klass, output)
    
        if self != NULL and success:
            success = output.printf(" obj 0x%lx", <long> self)

        if success:
            success = output.write(">")

    if not success:
        output.rewind(prev_pos)
        output.write("?>")
    return true


cdef inline bool type_repr(PyObject* ptr, TraceMessage* output):
    cdef int prev_pos

    if output.avail_size() < 9:  # enough room for <type ?>
        return false

    output.write("<type ")
    prev_pos = output.write_offset()
    if not write_type_name(<PyTypeObject*>ptr, output):
        output.rewind(prev_pos)
        output.write("?>")
    else:
        output.write(">")

    return true


cdef inline bool py_repr(PyObject* ptr, TraceMessage* output):
    cdef:
        PyObject* repr_obj
        Py_ssize_t repr_len
        char* repr_ptr

    # FIXME check NULL here
    repr_obj = PyObject_Repr(ptr)
    PyString_AsStringAndSize(repr_obj, &repr_ptr, &repr_len)
    try:
        return output.printf("%.*s", repr_len, repr_ptr)
    finally:
        Py_DECREF(repr_obj)


cdef inline bool obj_repr(PyObject* ptr, TraceMessage* output):
    return output.printf("<%s 0x%lx>", ptr.ob_type.tp_name, <long> ptr)


cdef inline bool fast_repr(PyObject* ptr, TraceMessage* output) with gil:
    if ptr == NULL:
        return output.write("<null>")
    elif PyInt_CheckExact(ptr):
        return int_repr(ptr, output)
    elif PyLong_CheckExact(ptr):
        return long_repr(ptr, output)
    elif PyFloat_CheckExact(ptr):
        return float_repr(ptr, output)
    elif PyString_CheckExact(ptr):
        return str_or_unicode_repr(false, ptr, output)
    elif PyUnicode_CheckExact(ptr):
        return str_or_unicode_repr(true, ptr, output)
    elif PyDict_CheckExact(ptr):
        return dict_repr(ptr, output)
    elif PyList_CheckExact(ptr):
        return list_or_tuple_repr(true, ptr, output)
    elif PyTuple_CheckExact(ptr):
        return list_or_tuple_repr(false, ptr, output)
    elif ptr == Py_None:
        return output.write("None")
    elif ptr == Py_True:
        return output.write("True")
    elif ptr == Py_False:
        return output.write("False")
    elif PyFunction_Check(ptr):
        return function_repr(<PyFunctionObject*>ptr, output)
    elif PyMethod_Check(ptr):
        return method_repr(ptr, output)
    elif PyType_Check(ptr):
        return type_repr(ptr, output)
    else:
        return obj_repr(ptr, output)
