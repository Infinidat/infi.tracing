import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tests"))
from utils import add_infi_tracing_to_sys_path
add_infi_tracing_to_sys_path()


from infi.tracing import (set_tracing, unset_tracing, tracing_output_to_file, NO_TRACE_NESTED)
from time import time
from contextlib import contextmanager
import greenlet


@contextmanager
def benchmark(label):
    try:
        start = time()
        yield
    finally:
        end = time()
        print("{} time: {}".format(label, end - start))


def green_bar():
    pass


def green_foo():
    green_bar()


def bar():
    pass


def foo():
    bar()
    g = greenlet.greenlet(green_foo)
    g.switch()


with benchmark("no tracing"):
    for i in xrange(1000000):
        foo()


def should_trace(frame):
    return NO_TRACE_NESTED

tracing_output_to_file(os.devnull)
set_tracing(should_trace)
with benchmark("with tracing"):
    for i in xrange(1000000):
        foo()
unset_tracing()
