__import__("pkg_resources").declare_namespace(__name__)
import sys
from infi.pyutils.contexts import contextmanager
from infi.pyutils.decorators import wraps

__all__ = ['set_tracing', 'unset_tracing', 'set_func_cache_size', 'suspend_tracing', 'resume_tracing',
           'no_tracing_context_recursive', 'no_tracing_recursive',
           'tracing_output_to_syslog', 'tracing_output_to_file', 'tracing_output_to_stdout', 'tracing_output_to_stderr',
           'NO_TRACE', 'NO_TRACE_NESTED', 'TRACE_FUNC_NAME', 'TRACE_FUNC_PRIMITIVES', 'TRACE_FUNC_REPR']

# Same as in ctracing:
NO_TRACE              = 0
NO_TRACE_NESTED       = 1
TRACE_FUNC_NAME       = 2
TRACE_FUNC_PRIMITIVES = 3
TRACE_FUNC_REPR       = 4


def _filter_all(*args, **kwargs):
    return True


def tracing_output_to_syslog(ident, facility):
    from infi.tracing.ctracing import ctracing_set_output_to_syslog
    ctracing_set_output_to_syslog(ident, facility)


def tracing_output_to_file(path):
    from infi.tracing.ctracing import ctracing_set_output_to_file
    ctracing_set_output_to_file(path)


def tracing_output_to_stdout():
    from infi.tracing.ctracing import ctracing_set_output_to_stdout
    ctracing_set_output_to_stdout()


def tracing_output_to_stderr():
    from infi.tracing.ctracing import ctracing_set_output_to_stderr
    ctracing_set_output_to_stderr()


def set_tracing(filter_func=_filter_all):
    from infi.tracing.ctracing import ctracing_set_profile, ctracing_start_trace_dump
    ctracing_start_trace_dump()
    ctracing_set_profile(filter_func)


def unset_tracing():
    from infi.tracing.ctracing import ctracing_stop_trace_dump
    sys.setprofile(None)
    ctracing_stop_trace_dump()


def set_func_cache_size(size):
    """Sets the function LRU cache size. The cache is used to determine whether to trace a function or not to trace it,
    and which level of tracing should be done."""
    from infi.tracing.ctracing import ctracing_set_func_cache_size
    ctracing_set_func_cache_size(size)


def suspend_tracing():
    from infi.tracing.ctracing import suspend
    suspend()


def resume_tracing():
    from infi.tracing.ctracing import resume
    resume()


@contextmanager
def no_tracing_context_recursive():
    try:
        suspend_tracing()
        yield
    finally:
        resume_tracing()

def no_tracing_recursive(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        with no_tracing_context_recursive():
            return func(*args, **kwargs)
    return wrapper
