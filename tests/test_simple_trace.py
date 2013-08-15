import sys
import os

import platform

os_name = platform.uname()[0].lower()
machine = platform.machine()
python_major_ver, python_minor_ver, _ = platform.python_version_tuple()
ver = "{}.{}".format(python_major_ver, python_minor_ver)

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "build", "lib.{}-{}-{}".format(os_name, machine, ver)))

from infi.tracing import set_tracing, unset_tracing, NO_TRACE, NO_TRACE_NESTED, TRACE_FUNC_NAME, TRACE_FUNC_PRIMITIVES


class Foo(object):
    def __init__(self):
        pass

    def foo(self):
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
    if frame.f_code.co_name  in ["foo", "bar", "foo_with_exception", "bar_with_exception", "kar_exception"]:
        return TRACE_FUNC_NAME
    if frame.f_code.co_name == "notrace_foo":
        return NO_TRACE
    if frame.f_code.co_name == "nested_notrace_foo":
        return NO_TRACE_NESTED
    return TRACE_FUNC_PRIMITIVES


print("setting profile")
set_tracing(trace_filter)

print("calling foo")
foo(42)

print("calling notrace_foo")
notrace_foo()

print("calling nested_notrace_foo")
nested_notrace_foo()

print("calling foo again")
foo(17)

print("calling foo_with_exception")
foo_with_exception()

func_with_arg(1)

func_with_arg("this is a string")

func_with_arg(3.1415)

func_with_arg(10**50)

func_with_arg(["this", "is", "list", 42])

func_with_arg({1: 'str_val', 'str_key': None})

func_with_arg('this is a long key that should be truncated ' * 10)

func_with_arg({'this is a long key that should be truncated ' * 10: 123})

func_with_vargs(1, 2)

func_with_vkwargs(a=1, b=2)

func_with_vargs_and_vwkargs(1, 2)

func_with_vargs_and_vwkargs(a=1, b=2)

func_with_vargs_and_vwkargs(1, 2, a=1, b=2)

func_with_args_and_vargs_and_vwkargs('a', 'b', 1, 2, a=1, b=2)

f = Foo()

f.foo()

func_with_arg(f)

func_with_arg(f.foo)

func_with_arg(Foo.foo)

func_with_arg(Foo)

func_with_arg(foo)

print("all done, unsetting profile")

unset_tracing()
