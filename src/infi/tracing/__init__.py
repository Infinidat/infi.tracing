__import__("pkg_resources").declare_namespace(__name__)
import sys

__all__ = ['set_profile', 'unset_profile', 'set_func_cache_size']


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
