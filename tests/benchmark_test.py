import sys
import os
from time import time
from contextlib import contextmanager

import platform

os_name = platform.uname()[0].lower()
machine = platform.machine()
python_major_ver, python_minor_ver, _ = platform.python_version_tuple()
ver = "{}.{}".format(python_major_ver, python_minor_ver)

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "build", "lib.{}-{}-{}".format(os_name, machine, ver)))

print sys.path

from infi.tracing import set_profile, unset_profile, NO_TRACE, TRACE_FUNC_NAME


@contextmanager
def benchmark(label):
    try:
        start = time()
        yield
    finally:
        end = time()
        print("{} time: {:.4f}".format(label, end - start))


def bar():
    pass


def foo():
    bar()


with benchmark("no profile set"):
    for i in xrange(1000000):
        foo()


def trace_filter(code):
    print("trace_filter {}".format(code.co_name))
    return NO_TRACE


set_profile(trace_filter)

with benchmark("infi.tracing.set_profile set"):
    for i in xrange(1000000):
        foo()

unset_profile()
