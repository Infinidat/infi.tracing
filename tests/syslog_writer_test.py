import sys
import os

import platform

os_name = platform.uname()[0].lower()
machine = platform.machine()
python_major_ver, python_minor_ver, _ = platform.python_version_tuple()
ver = "{}.{}".format(python_major_ver, python_minor_ver)

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "build", "lib.{}-{}-{}".format(os_name, machine, ver)))

from infi.tracing import SyslogWriter
import syslog

writer = SyslogWriter(16384, 4096, syslog.LOG_LOCAL0 >> 3, address=("127.0.0.1", 6514), host_name="myhost",
                      application_name="syslog_writer_test", process_id="main", rfc5424=True)
writer.start()

writer.write(syslog.LOG_DEBUG, "hello world!")

writer.stop()
