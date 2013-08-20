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
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "src"))

print sys.path

from infi.tracing import set_tracing, unset_tracing, TRACE_FUNC_PRIMITIVES


SAMPLES = 5
ITERS = 1000000

def print_samples(label, samples, baseline_avg=None):
    avg = sum(samples) / len(samples)
    buf = ["{:20}: {}: avg. {:.3f}".format(label, ",".join("{:.3f}".format(s) for s in samples), avg)]
    if baseline_avg is not None:
        buf.append("({:.2f} times from baseline)".format(avg / baseline_avg))

    print(" ".join(buf))


@contextmanager
def benchmark(samples):
    try:
        start = time()
        yield
    finally:
        end = time()
        samples.append(end - start)
        print("sample result: {:.3f}".format(end - start))

def bar():
    pass


def foo():
    bar()


np_samples = []
for si in xrange(SAMPLES):
    with benchmark(np_samples) as sample:
        for i in xrange(ITERS):
            foo()



def trace_filter(frame):
    print("trace_filter {}".format(frame.f_code.co_name))
    return TRACE_FUNC_PRIMITIVES


set_tracing(trace_filter)

p_samples = []
for si in xrange(SAMPLES):
    with benchmark(p_samples):
        for i in xrange(ITERS):
            foo()

print_samples("no profiling", np_samples)
print_samples("profiling", p_samples, sum(np_samples) / len(np_samples))

unset_tracing()
