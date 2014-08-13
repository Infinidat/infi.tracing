import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from utils import add_infi_tracing_to_sys_path
add_infi_tracing_to_sys_path()


import re
import tempfile
from infi.tracing import (set_tracing, unset_tracing, tracing_output_to_file, NO_TRACE, NO_TRACE_NESTED,
                          TRACE_FUNC_NAME, TRACE_FUNC_PRIMITIVES)


class Foo(object):
    def __init__(self):
        pass

    def foo(self):
        pass

    def this_is_a_very_long_method_name_so_it_should_get_truncated_somehow(self):
        pass


def bar(n):
    pass


def foo(n):
    bar(n - 1)


def notrace_foo():
    foo(12)


def nested_notrace_foo():
    foo(32)


def kar_exception():
    print("kar_exception is raising an exception now.")
    raise Exception("boo")


def bar_with_exception():
    kar_exception()


def foo_with_exception():
    try:
        bar_with_exception()
    except:
        pass


def func_with_arg(arg):
    pass


def func_with_vargs(*vargs):
    pass


def func_with_vkwargs(**kwargs):
    pass


def func_with_vargs_and_vwkargs(*args, **kwargs):
    pass


def func_with_args_and_vargs_and_vwkargs(arg1, arg2, *args, **kwargs):
    pass


def trace_filter(frame):
    print("trace_filter {}".format(frame.f_code.co_name))
    if frame.f_code.co_name == 'compile':  # our test's re.compile...
        return NO_TRACE_NESTED
    if frame.f_code.co_name in ["foo", "bar"]:
        return TRACE_FUNC_NAME
    if frame.f_code.co_name == "notrace_foo":
        return NO_TRACE
    if frame.f_code.co_name == "nested_notrace_foo":
        return NO_TRACE_NESTED
    return TRACE_FUNC_PRIMITIVES


log_file = tempfile.mktemp()
print("temporary log file: {}".format(log_file))
tracing_output_to_file(log_file)
expected_output = []
set_tracing(trace_filter)
expected_output.append(("<", "infi.tracing", "set_tracing,None"))

foo(42)
expected_output.extend([
    (">", "__main__", "foo"),
    (">", "__main__", "bar"),
    ("<", "__main__", "bar"),
    ("<", "__main__", "foo"),
])

notrace_foo()
expected_output.extend([  # notrace_foo not traced
    (">", "__main__", "foo"),
    (">", "__main__", "bar"),
    ("<", "__main__", "bar"),
    ("<", "__main__", "foo"),
])

nested_notrace_foo()

foo(17)
expected_output.extend([
    (">", "__main__", "foo"),
    (">", "__main__", "bar"),
    ("<", "__main__", "bar"),
    ("<", "__main__", "foo"),
])

foo_with_exception()
expected_output.extend([
    (">", "__main__", "foo_with_exception"),
    (">", "__main__", "bar_with_exception"),
    (">", "__main__", "kar_exception"),
    ("<", "__main__", "kar_exception,exc"),
    ("<", "__main__", "bar_with_exception,exc"),
    ("<", "__main__", "foo_with_exception,None"),
])

func_with_arg(1)
expected_output.extend([
    (">", "__main__", "func_with_arg,1"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(None)
expected_output.extend([
    (">", "__main__", "func_with_arg,None"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(True)
expected_output.extend([
    (">", "__main__", "func_with_arg,True"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(False)
expected_output.extend([
    (">", "__main__", "func_with_arg,False"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg("this is a string")
expected_output.extend([
    (">", "__main__", "func_with_arg,'this is a string'"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(3.1415)
expected_output.extend([
    (">", "__main__", "func_with_arg,3.1415f"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(10**50)
expected_output.extend([
    (">", "__main__", "func_with_arg,100000000000000000000000000000000000000000000000000"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(["this", "is", "list", 42])
expected_output.extend([
    (">", "__main__", "func_with_arg,['this','is','list',42]"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg({1: 'str_val', 'str_key': None})
expected_output.extend([
    (">", "__main__", "func_with_arg,{1:'str_val','str_key':None}"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg('this is a long key that should be truncated ' * 10)
expected_output.extend([
    (">", "__main__", "func_with_arg,'this is a long key that should be truncated this is a long key t'... <len=440>"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg({'this is a long key that should be truncated ' * 10: 123})
expected_output.extend([
    (">", "__main__", "func_with_arg,{'this is a long k'... <len=440>:123}"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_vargs(1, 2)
expected_output.extend([
    (">", "__main__", "func_with_vargs,vargs=(1,2)"),
    ("<", "__main__", "func_with_vargs,None")
])
func_with_vkwargs(a=1, b=2)
expected_output.extend([
    (">", "__main__", "func_with_vkwargs,kwargs={'a':1,'b':2}"),
    ("<", "__main__", "func_with_vkwargs,None")
])
func_with_vargs_and_vwkargs(1, 2)
expected_output.extend([
    (">", "__main__", "func_with_vargs_and_vwkargs,vargs=(1,2),kwargs={}"),
    ("<", "__main__", "func_with_vargs_and_vwkargs,None")
])
func_with_vargs_and_vwkargs(a=1, b=2)
expected_output.extend([
    (">", "__main__", "func_with_vargs_and_vwkargs,vargs=(),kwargs={'a':1,'b':2}"),
    ("<", "__main__", "func_with_vargs_and_vwkargs,None")
])
func_with_vargs_and_vwkargs(1, 2, a=1, b=2)
expected_output.extend([
    (">", "__main__", "func_with_vargs_and_vwkargs,vargs=(1,2),kwargs={'a':1,'b':2}"),
    ("<", "__main__", "func_with_vargs_and_vwkargs,None")
])
func_with_args_and_vargs_and_vwkargs('a', 'b', 1, 2, a=1, b=2)
expected_output.extend([
    (">", "__main__", "func_with_args_and_vargs_and_vwkargs,'a','b',vargs=(1,2),kwargs={'a':1,'b':2}"),
    ("<", "__main__", "func_with_args_and_vargs_and_vwkargs,None")
])
f = Foo()
expected_output.extend([
    (">", "__main__", re.compile("__init__,<Foo 0x.*>")),
    ("<", "__main__", "__init__,None")
])
f.foo()
expected_output.extend([
    (">", "__main__", "foo"),
    ("<", "__main__", "foo")
])
func_with_arg(f)
expected_output.extend([
    (">", "__main__", re.compile("func_with_arg,<Foo 0x.*>")),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(f.foo)
expected_output.extend([
    (">", "__main__", re.compile("func_with_arg,<meth foo cls Foo obj 0x.*>")),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(Foo.foo)
expected_output.extend([
    (">", "__main__", "func_with_arg,<meth foo cls Foo>"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(Foo)
expected_output.extend([
    (">", "__main__", "func_with_arg,<type Foo>"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg(foo)
expected_output.extend([
    (">", "__main__", "func_with_arg,<func foo>"),
    ("<", "__main__", "func_with_arg,None")
])
func_with_arg((f.this_is_a_very_long_method_name_so_it_should_get_truncated_somehow, func_with_vkwargs))
expected_output.extend([
    (">", "__main__", "func_with_arg,(<meth ?>,<func func_with_vkwargs>)"),
    ("<", "__main__", "func_with_arg,None")
])

unset_tracing()
expected_output.append((">", "infi.tracing", "unset_tracing"))

from infi.tracing.ctracing import ctracing_print_stats
ctracing_print_stats()

with open(log_file, "rb") as f:
    lines = f.readlines()

has_overflows = False


def is_overflow(l):
    global has_overflows
    if "messages due to overflow" in l:
        has_overflows = True
        return True
    return False
lines = [l.strip() for l in lines if not is_overflow(l)]


def compare_lines(expected, actual, received):
    for expected_e, actual_e in zip(expected, actual):
        if isinstance(expected_e, (unicode, str)):
            if expected_e != actual_e:
                raise AssertionError("expected {!r} but got {!r} ({!r})".format(expected_e, actual_e, received))
        elif not expected_e.match(actual_e):
            raise AssertionError("expected {} but got {!r} ({!r})".format(expected_e, actual_e, received))

from itertools import izip
for expected, received in izip(expected_output, lines):
    try:
        d, _, _, mod, func_w_args = received.split(",", 4)
    except ValueError:
        raise AssertionError("got {!r} not conforming to line format".format(received))
    actual = (d, mod, func_w_args)
    compare_lines(expected, actual, received)

if len(expected_output) != len(lines):
    raise AssertionError("expected output length {} != actual length {}".format(len(expected_output), len(lines)))

if has_overflows:
    raise AssertionError("found overflows")
