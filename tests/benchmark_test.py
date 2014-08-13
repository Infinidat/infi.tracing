import sys
import os
from time import time

import glob
lib_path = glob.glob(os.path.join(os.path.dirname(__file__), "..", "build", "lib.*"))[0]
sys.path.insert(0, lib_path)
sys.path.insert(0, os.path.dirname(__file__))

from infi.tracing import (set_tracing, unset_tracing, tracing_output_to_syslog,  # tracing_output_to_file,
                          TRACE_FUNC_PRIMITIVES)
from syslog import LOG_LOCAL0

SAMPLES = 5
CUT_OFF_TIME = 5.0


def print_samples(label, samples, baseline_avg=None):
    avg = sum(samples) / len(samples)
    min_sample, max_sample = min(samples), max(samples)
    buf = ["{:8}:".format(label),
           ", ".join("{:10.2f}".format(s) for s in samples),
           "min/avg d {:5.2f}%".format(100.0 * (min_sample - avg) / avg),
           "max/avg d {:5.2f}%".format(100.0 * (max_sample - avg) / avg)]
    if baseline_avg is not None:
        buf.append("({:.2f} times slower than baseline)".format(baseline_avg / avg))
    print("  {}".format(" ".join(buf)))


def benchmark(samples, func):
    start = time()
    iters = 0
    now = time()
    while (now - start) < CUT_OFF_TIME:
        func()
        iters += 1
        now = time()
    iters_per_sec = float(iters) / float(now - start)
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


tracing_output_to_syslog(LOG_LOCAL0, application_name="benchmark")
# tracing_output_to_file("/tmp/trace.log")
set_tracing(trace_filter)

p_samples = []
for si in xrange(SAMPLES):
    benchmark(p_samples, foo)

unset_tracing()

print_samples("baseline", np_samples)
print_samples("test", p_samples, sum(np_samples) / len(np_samples))

from infi.tracing.ctracing import ctracing_print_stats
ctracing_print_stats()
