__import__("pkg_resources").declare_namespace(__name__)
import sys

__all__ = ['set_profile', 'unset_profile', 'set_func_cache_size', 'NO_TRACE', 'NO_TRACE_NESTED', 
           'TRACE_FUNC_NAME', 'TRACE_FUNC_PRIMITIVES', 'TRACE_FUNC_REPR']

# Same as in ctracing:
NO_TRACE              = 0
NO_TRACE_NESTED       = 1
TRACE_FUNC_NAME       = 2
TRACE_FUNC_PRIMITIVES = 3
TRACE_FUNC_REPR       = 4

def _filter_all(*args, **kwargs):
    return True


def set_profile(filter_func=_filter_all):
    from infi.tracing.ctracing import ctracing_set_profile
    ctracing_set_profile(filter_func)


def unset_profile():
    sys.setprofile(None)


def set_func_cache_size(size):
    """Sets the function LRU cache size. The cache is used to determine whether to trace a function or not to trace it,
    and which level of tracing should be done."""
    from infi.tracing.ctracing import ctracing_set_func_cache_size
    ctracing_set_func_cache_size(size)
