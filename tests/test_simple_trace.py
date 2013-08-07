import sys
import os

import platform

os_name = platform.uname()[0].lower()
machine = platform.machine()
python_major_ver, python_minor_ver, _ = platform.python_version_tuple()
ver = "{}.{}".format(python_major_ver, python_minor_ver)

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "build", "lib.{}-{}-{}".format(os_name, machine, ver)))

print sys.path

from infi.tracing import set_profile, unset_profile, NO_TRACE, NO_TRACE_NESTED, TRACE_FUNC_NAME


def bar():
    pass


def foo():
    bar()


def notrace_foo():
    foo()

def nested_notrace_foo():
    foo()


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

def trace_filter(code):
    print("trace_filter {}".format(code.co_name))
    if code.co_name  in ["foo", "bar", "foo_with_exception", "bar_with_exception", "kar_exception"]:
        return TRACE_FUNC_NAME
    if code.co_name == "notrace_foo":
        return NO_TRACE
    if code.co_name == "nested_notrace_foo":
        return NO_TRACE_NESTED
    return TRACE_FUNC_NAME


print("setting profile")
set_profile(trace_filter)

print("calling foo")
foo()

print("calling notrace_foo")
notrace_foo()

print("calling nested_notrace_foo")
nested_notrace_foo()

print("calling foo again")
foo()

print("calling foo_with_exception")
foo_with_exception()

print("all done, unsetting profile")

from infi.tracing.ctracing import call_log
print("call_log size: {}".format(len(call_log)))
unset_profile()
