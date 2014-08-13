import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from utils import add_infi_tracing_to_sys_path
add_infi_tracing_to_sys_path()

if sys.platform != 'win32':
    from infi.tracing import SyslogWriter
    import syslog

    writer = SyslogWriter(16384, 4096, syslog.LOG_LOCAL0 >> 3, address=("127.0.0.1", 6514), host_name="myhost",
                          application_name="syslog_writer_test", process_id="main", rfc5424=True)
    writer.start()

    writer.write(syslog.LOG_DEBUG, "hello world!")

    writer.stop()
else:
    print("syslog not supported on win32, skipping.")
