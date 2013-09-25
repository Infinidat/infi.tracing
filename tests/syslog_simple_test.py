import sys
import os

import platform

os_name = platform.uname()[0].lower()
machine = platform.machine()
python_major_ver, python_minor_ver, _ = platform.python_version_tuple()
ver = "{}.{}".format(python_major_ver, python_minor_ver)

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "build", "lib.{}-{}-{}".format(os_name, machine, ver)))

from infi.tracing import (set_tracing, unset_tracing, tracing_output_to_syslog, NO_TRACE_NESTED, TRACE_FUNC_PRIMITIVES)

def bar(n):
    pass


def foo(n):
    bar(n - 1)


def trace_filter(frame):
    print("trace_filter {}".format(frame.f_code.co_name))
    if frame.f_code.co_name  in ["foo", "bar"]:
        return TRACE_FUNC_PRIMITIVES
    return NO_TRACE_NESTED


print("setting profile")
from syslog import LOG_LOCAL0
# tracing_output_to_syslog(LOG_LOCAL0, "ctracing_test")
tracing_output_to_syslog(LOG_LOCAL0 >> 3, host_name="myhost", application_name="ctracing_test", process_id="myproc",
                         rfc5424=True, address=("127.0.0.1", 6514))
set_tracing(trace_filter)

print("calling foo")
foo(42)

print("all done, unsetting profile")

unset_tracing()

from infi.tracing.ctracing import ctracing_print_stats
ctracing_print_stats()
