from trace_dump cimport (TraceDump, FileTraceDump, SyslogTraceDump, SyslogSocket, SyslogUNIXSocket, SyslogTCPSocket)
from libc.stdio cimport FILE, fopen, fclose, stdout, stderr

cdef class PyTraceDump:
    cdef TraceDump* thisptr

    def __dealloc__(self):
        del self.thisptr

    def start(self):
        self.thisptr.start()

    def stop(self):
        self.thisptr.stop()


cdef class PyFileTraceDump(PyTraceDump):
    def __cinit__(self, const char* path):
        global trace_message_ring_buffer
        cdef FILE* handle = fopen(path, "wb")
        if handle == NULL:
            raise ValueError("cannot open file {}".format(path))
        self.thisptr = new FileTraceDump(trace_message_ring_buffer, handle, True)


cdef class PyStdoutTraceDump(PyTraceDump):
    def __cinit__(self):
        global trace_message_ring_buffer
        self.thisptr = new FileTraceDump(trace_message_ring_buffer, stdout, False)


cdef class PyStderrTraceDump(PyTraceDump):
    def __cinit__(self):
        global trace_message_ring_buffer
        self.thisptr = new FileTraceDump(trace_message_ring_buffer, stderr, False)


cdef class PySyslogTraceDump(PyTraceDump):
    def __cinit__(self):
        self.thisptr = NULL


cdef new_syslog_trace_dump(const char* host_name, const char* application_name, const char* process_id, int facility,
                           bool rfc5424, SyslogSocket* socket):
    global trace_message_ring_buffer
    cdef SyslogTraceDump* trace_dump = new SyslogTraceDump(trace_message_ring_buffer, host_name, application_name,
                                                           process_id, facility, rfc5424, socket)
    result = PySyslogTraceDump()
    result.thisptr = trace_dump
    return result


def PySyslogTraceDump_create_with_unix_socket(const char* host_name, const char* application_name,
                                              const char* process_id, int facility, bool rfc5424, const char* address):
    cdef SyslogUNIXSocket* socket = new SyslogUNIXSocket(address)
    return new_syslog_trace_dump(host_name, application_name, process_id, facility, rfc5424, socket)


def PySyslogTraceDump_create_with_tcp_socket(const char* host_name, const char* application_name,
                                             const char* process_id, int facility, bool rfc5424, const char* address,
                                             int port):
    cdef SyslogTCPSocket* socket = new SyslogTCPSocket(address, port)
    return new_syslog_trace_dump(host_name, application_name, process_id, facility, rfc5424, socket)


cdef class PyWriter:
    cdef TraceMessageRingBuffer* ring_buffer
    cdef TraceDump* trace_dump

    def __cinit__(self):
        self.ring_buffer = NULL
        self.trace_dump = NULL

    def __dealloc__(self):
        self.trace_dump.stop()
        del self.trace_dump
        del self.ring_buffer

    def start(self):
        self.trace_dump.start()

    def stop(self):
        self.trace_dump.stop()

    def write(self, severity, message_str):
        cdef TraceMessage* message = self.ring_buffer.reserve_push()
        message.set_timestamp()
        message.set_severity(severity)
        message.write(message_str)
        self.ring_buffer.commit_push(message)


cdef new_syslog_writer(int buffer_size, int trace_message_size, const char* host_name, const char* application_name, 
                       const char* process_id, int facility, bool rfc5424, SyslogSocket* socket):
    cdef TraceMessageRingBuffer* ring_buffer = new TraceMessageRingBuffer(buffer_size, trace_message_size)
    cdef SyslogTraceDump* trace_dump = new SyslogTraceDump(ring_buffer, host_name, application_name, process_id,
                                                           facility, rfc5424, socket)
    result = PyWriter()
    result.ring_buffer = ring_buffer
    result.trace_dump = trace_dump
    return result

def PySyslogWriter_create_with_unix_socket(int buffer_size, int trace_message_size, const char* host_name, 
                                           const char* application_name, const char* process_id, int facility, 
                                           bool rfc5424, const char* address):
    cdef SyslogSocket* socket = new SyslogUNIXSocket(address)
    return new_syslog_writer(buffer_size, trace_message_size, host_name, application_name, process_id, facility, 
                             rfc5424, socket)


def PySyslogWriter_create_with_tcp_socket(int buffer_size, int trace_message_size, const char* host_name, 
                                          const char* application_name, const char* process_id, int facility, 
                                          bool rfc5424, const char* address, int port):
    cdef SyslogSocket* socket = new SyslogTCPSocket(address, port)
    return new_syslog_writer(buffer_size, trace_message_size, host_name, application_name, process_id, facility, 
                             rfc5424, socket)
