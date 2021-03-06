import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tests"))
from utils import add_infi_tracing_to_sys_path
add_infi_tracing_to_sys_path()


import resource
from time import time


def foo():
    pass


def foo_with_arg(arg):
    pass


def get_and_print_maxrss(baserss=None):
    maxrss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    if baserss is not None:
        print("maxrss={} (base={}, delta={:.2f}%)".format(maxrss, baserss, float(maxrss - baserss) * 100 / baserss))
    else:
        print("maxrss={}".format(maxrss))
    return maxrss


def setup_tracing():
    from infi.tracing import (set_tracing, tracing_output_to_syslog, TRACE_FUNC_PRIMITIVES)
    from syslog import LOG_LOCAL0

    def should_trace(frame):
        return TRACE_FUNC_PRIMITIVES

    tracing_output_to_syslog(LOG_LOCAL0, application_name="infi-tracing")
    set_tracing(should_trace)


def teardown_tracing():
    from infi.tracing import unset_tracing
    unset_tracing()


def run():
    foo()
    foo_with_arg(1)
    foo_with_arg([1, 2, 3])
    foo_with_arg({'a': 1, 'b': 2, 'c': [1, 2, 3], 'd': 213.22, 'e': u'asdasdasd', 'f': 'asdasdasdasd'})

    def func():
        pass

    foo_with_arg(func)

    import greenlet
    g = greenlet.greenlet(foo)
    g.switch()


def main():
    setup_tracing()

    last_time = time()
    base_rss = get_and_print_maxrss()
    while True:
        try:
            run()
            t = time()
            if t - last_time >= 5:
                last_time = t
                get_and_print_maxrss(base_rss)
        except KeyboardInterrupt:
            print("Ctrl-C caught, exitting.")
            break

    teardown_tracing()

if __name__ == "__main__":
    if sys.platform != 'win32':
        main()
    else:
        print("skipping on win32 platform.")
