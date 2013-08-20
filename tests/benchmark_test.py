import sys
import os
from time import time

import platform

os_name = platform.uname()[0].lower()
machine = platform.machine()
python_major_ver, python_minor_ver, _ = platform.python_version_tuple()
ver = "{}.{}".format(python_major_ver, python_minor_ver)

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "build", "lib.{}-{}-{}".format(os_name, machine, ver)))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "src"))

from infi.tracing import set_tracing, unset_tracing, TRACE_FUNC_PRIMITIVES

SAMPLES = 5
CUT_OFF_TIME = 5.0

def print_samples(label, samples, baseline_avg=None):
    avg = sum(samples) / len(samples)
    min_sample, max_sample = min(samples), max(samples)
    buf = ["{:20}:".format(label),
           ", ".join("{:10.2f}".format(s) for s in samples),
           "avg. {:10.2f}".format(avg),
           "min d {:5.2f}%".format(100.0 * (min_sample - avg) / avg),
           "max d {:5.2f}%".format(100.0 * (max_sample - avg) / avg)]
    if baseline_avg is not None:
        buf.append("({:.2f} times slower from baseline)".format((baseline_avg - avg) / avg))
    
    print(" ".join(buf))


def benchmark(samples, func):
    start = time()
    iters = 0
    now = time()
    while (now - start) < CUT_OFF_TIME:
        func()
        iters += 1
        now = time()
    iters_per_sec = float(iters)  / float(now - start)
    samples.append(iters_per_sec)
    print("sample result (iters/sec): {:.2f}".format(iters_per_sec))

def bar():
    pass


def foo():
    bar()


np_samples = []
for si in xrange(SAMPLES):
    benchmark(np_samples, foo)


def trace_filter(frame):
    # print("trace_filter {}".format(frame.f_code.co_name))
    return TRACE_FUNC_PRIMITIVES


set_tracing(trace_filter)

p_samples = []
for si in xrange(SAMPLES):
    benchmark(p_samples, foo)

print_samples("no profiling", np_samples)
print_samples("profiling", p_samples, sum(np_samples) / len(np_samples))

unset_tracing()
