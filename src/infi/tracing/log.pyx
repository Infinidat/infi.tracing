from defs cimport *

call_log = []

from inspect import getargvalues
from weakref import WeakKeyDictionary
blacklist_objects = WeakKeyDictionary()

# Taken from Python's stdlib inspect.py:
import string

def joinseq(seq):
    if len(seq) == 1:
        return '(' + seq[0] + ',)'
    else:
        return '(' + string.join(seq, ', ') + ')'

def strseq(object, convert, join=joinseq):
    """Recursively walk a sequence, stringifying each element."""
    if type(object) in (list, tuple):
        return join(map(lambda o, c=convert, j=join: strseq(o, c, j), object))
    else:
        return convert(object)

def formatvalue(value):
    if value in blacklist_objects:
        return '=<norepr>'

    try:
        return '=' + repr(value)
    except:
        blacklist_objects[value] = True
        return '=<norepr>'

def formatargvalues(args, varargs, varkw, locals,
                    formatarg=str,
                    formatvarargs=lambda name: '*' + name,
                    formatvarkw=lambda name: '**' + name,
                    formatvalue=formatvalue,
                    join=joinseq):
    """Format an argument spec from the 4 values returned by getargvalues.

    The first four arguments are (args, varargs, varkw, locals).  The
    next four arguments are the corresponding optional formatting functions
    that are called to turn names and values into strings.  The ninth
    argument is an optional function to format the sequence of arguments."""
    def convert(name, locals=locals,
                formatarg=formatarg, formatvalue=formatvalue):
        return formatarg(name) + formatvalue(locals[name])
    specs = []
    for i in range(len(args)):
        if args[i] in blacklist_objects:
            s = "<norepr>"
        else:
            try:
                s = strseq(args[i], convert, join)
            except:
                s = "<norepr>"
                blacklist_objects[args[i]] = True
        specs.append(s)
    if varargs:
        specs.append(formatvarargs(varargs) + formatvalue(locals[varargs]))
    if varkw:
        specs.append(formatvarkw(varkw) + formatvalue(locals[varkw]))
    return '(' + string.join(specs, ', ') + ')'

cdef void log_call(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    global call_log
    cdef int line_no
    with gil:
        line_no = PyFrame_GetLineNumber(frame)
        fname = frame.f_code.co_filename
        name = frame.f_code.co_name

        try:
            pretty_argument_spec = formatargvalues(*getargvalues(<object>frame))
            if pretty_argument_spec > 256:
                pretty_argument_spec = str(pretty_argument_spec)[0:256] + "...)"
        except:
            pretty_argument_spec = "(...)"
        log_str = "{} ({}) > {}{} {}:{}".format(gid, depth, <object>name, pretty_argument_spec, <object>fname, line_no)

        # call_log.append((0, gid, depth, "{}:{}:{}".format(<object>name, <object> fname, line_no)))
        # call_log.append((0, gid, depth, <object>name, <object>fname, line_no))
        # print("> ({}:{}) {} [{}:{}]".format(gid, depth, <object>name, <object>fname, line_no))


cdef void log_return(int trace_level, long gid, long depth, PyFrameObject* frame, PyObject* arg) nogil:
    global call_log
    cdef int line_no
    with gil:
        line_no = PyFrame_GetLineNumber(frame)
        fname = frame.f_code.co_filename
        name = frame.f_code.co_name

        if arg == NULL:
            # call_log.append((1, gid, depth, "E {}:{}:{}".format(<object>name, <object> fname, line_no)))
            # call_log.append((1, gid, depth, <object>name, <object>fname, line_no, None))

            log_str = "{} ({}) > {} = ERROR {}:{}".format(gid, depth, <object>name, <object>fname, line_no)
        else:
            try:
                return_value = repr(<object>arg)
                if len(return_value) > 256:
                    return_value = object.__repr__(<object>arg)
            except:
                return_value = "(...)"

            log_str = "{} ({}) > {} = {} {}:{}".format(gid, depth, <object>name, return_value, <object>fname, line_no)
            # call_log.append((1, gid, depth, "{}:{}:{}".format(<object>name, <object> fname, line_no)))
            # call_log.append((1, gid, depth, <object>name, <object>fname, line_no, <object>arg))

    # if arg == NULL:
    #     with gil:
    #         print("< ({}:{}) {} : NULL (Exception)".format(gid, depth, (<object>frame.f_code).co_name))
    # else:
    #     with gil:
    #         print("< ({}:{}) {} : {}".format(gid, depth, (<object>frame.f_code).co_name, <object>arg))

