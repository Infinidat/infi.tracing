__import__("pkg_resources").declare_namespace(__name__)
import sys
from infi.pyutils.contexts import contextmanager
from infi.pyutils.decorators import wraps

__all__ = ['set_tracing', 'unset_tracing', 'set_func_cache_size', 'suspend_tracing', 'resume_tracing',
           'no_tracing_context_recursive', 'no_tracing_recursive',
           'tracing_output_to_syslog', 'tracing_output_to_file', 'tracing_output_to_stdout', 'tracing_output_to_stderr',
           'NO_TRACE', 'NO_TRACE_NESTED', 'TRACE_FUNC_NAME', 'TRACE_FUNC_PRIMITIVES', 'TRACE_FUNC_REPR',
           'SyslogWriter']

# Same as in ctracing:
NO_TRACE              = 0
NO_TRACE_NESTED       = 1
TRACE_FUNC_NAME       = 2
TRACE_FUNC_PRIMITIVES = 3
TRACE_FUNC_REPR       = 4

trace_dump = None

def _filter_all(*args, **kwargs):
    return True


def tracing_output_to_syslog(facility, host_name="", application_name="", process_id="", address=None, rfc5424=False):
    global trace_dump
    from infi.tracing.ctracing import (PySyslogTraceDump_create_with_unix_socket,
                                       PySyslogTraceDump_create_with_tcp_socket)
    _check_syslog_application_name_and_facility(application_name, facility)
    if address is None:
        address = default_syslog_address()
    if (_check_syslog_address(address) == 'tcp'):
        trace_dump = PySyslogTraceDump_create_with_tcp_socket(host_name, application_name, process_id, facility,
                                                              bool(rfc5424), address[0], address[1])
    else:
        trace_dump = PySyslogTraceDump_create_with_unix_socket(host_name, application_name, process_id, facility,
                                                               bool(rfc5424), address)

def tracing_output_to_file(path):
    global trace_dump
    from infi.tracing.ctracing import PyFileTraceDump
    trace_dump = PyFileTraceDump(path)


def tracing_output_to_stdout():
    global trace_dump
    from infi.tracing.ctracing import PyStdoutTraceDump
    trace_dump = PyStdoutTraceDump()


def tracing_output_to_stderr():
    global trace_dump
    from infi.tracing.ctracing import PyStderrTraceDump
    trace_dump = PyStderrTraceDump()


def set_tracing(filter_func=_filter_all):
    global trace_dump
    from infi.tracing.ctracing import ctracing_set_profile
    if trace_dump:
        trace_dump.start()
    ctracing_set_profile(filter_func)


def unset_tracing():
    global trace_dump
    sys.setprofile(None)
    if trace_dump:
        trace_dump.stop()
        trace_dump = None


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


def default_syslog_address():
    import os
    import sys
    if sys.platform == 'darwin':
        address = '/var/run/syslog'
    else:
        address = '/dev/log'
    if not os.path.exists(address):
        raise ValueError("cannot find syslog socket address: {}".format(address))
    return address


def _check_syslog_application_name_and_facility(application_name, facility):
    if not isinstance(application_name, (str, unicode)):
        raise TypeError("application_name must be a string or unicode object")

    if not isinstance(facility, int):
        raise TypeError("facility must be an int object")

def _check_syslog_address(address):
    import os
    if isinstance(address, (str, unicode)):
        # UNIX socket:
        if not os.path.exists(address):
            raise ValueError("cannot find syslog socket address: {}".format(address))
        return 'unix'
    else:
        import re
        if not isinstance(address, (tuple, list)):
            raise TypeError("syslog address must be a string or an (addr, port) pair")
        if not re.match(r'\d+\.\d+\.\d+\.\d+', address[0]):
            raise ValueError("syslog address first element must be an IP address but got {!r}".format(address[0]))
        return 'tcp'

def SyslogWriter(buffer_size, trace_message_size, facility, address=None, host_name="", application_name="", 
                 process_id="", rfc5424=False):
    from infi.tracing.ctracing import (PySyslogWriter_create_with_unix_socket, PySyslogWriter_create_with_tcp_socket)
    _check_syslog_application_name_and_facility(application_name, facility)
    if address is None:
        address = default_syslog_address()
    if _check_syslog_address(address) == 'tcp':
        return PySyslogWriter_create_with_tcp_socket(buffer_size, trace_message_size, host_name, application_name,
                                                     process_id, facility, bool(rfc5424), address[0], address[1])
    else:
        return PySyslogWriter_create_with_unix_socket(buffer_size, trace_message_size, host_name, application_name,
                                                      process_id, facility, bool(rfc5424), address)
