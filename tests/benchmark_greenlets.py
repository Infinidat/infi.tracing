import sys
import os
from time import time
from contextlib import contextmanager

sys.path.append(os.path.dirname(__name__))

from cytest.native import cytest_setprofile
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


# with benchmark("no profile set"):
#     for i in xrange(1000000):
#         foo()


# cytest_setprofile()

# with benchmark("cytest_setprofile set"):
#     for i in xrange(1000000):
#         foo()

cytest_setprofile()
import cytest.native

def should_trace(code):
    print("should_trace {}".format(code))
    return False

cytest.native.should_trace_code = should_trace

foo()
foo()

sys.setprofile(None)
print("no more profiling")
