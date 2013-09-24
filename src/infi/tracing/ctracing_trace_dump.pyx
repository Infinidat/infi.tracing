from trace_dump cimport (TraceDump, FileTraceDump, SyslogTraceDump,
                         SyslogTraceDump_create_with_unix_socket, SyslogTraceDump_create_with_tcp_socket)
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


def PySyslogTraceDump_create_with_unix_socket(const char* host_name, const char* application_name,
                                              const char* process_id, int facility, bool rfc5424, const char* address):
    global trace_message_ring_buffer
    result = PySyslogTraceDump()
    result.thisptr = SyslogTraceDump_create_with_unix_socket(trace_message_ring_buffer, host_name, application_name,
                                                             process_id, facility, rfc5424, address)
    return result


def PySyslogTraceDump_create_with_tcp_socket(const char* host_name, const char* application_name,
                                             const char* process_id, int facility, bool rfc5424, const char* address,
                                             int port):
    global trace_message_ring_buffer
    result = PySyslogTraceDump()
    result.thisptr = SyslogTraceDump_create_with_tcp_socket(trace_message_ring_buffer, host_name, application_name,
                                                            process_id, facility, rfc5424, address, port)
    return result


cdef class PySyslogWriter:
    cdef TraceDump* trace_dump
    cdef TraceMessageRingBuffer* ring_buffer

    def __cinit__(self, int buffer_size):
        self.ring_buffer = new TraceMessageRingBuffer(buffer_size)
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


def PySyslogWriter_create_with_unix_socket(int buffer_size, const char* host_name, const char* application_name,
                                           const char* process_id, int facility, bool rfc5424, const char* address):
    result = PySyslogWriter(buffer_size)
    result.trace_dump = SyslogTraceDump_create_with_unix_socket(result.ring_buffer, host_name, application_name,
                                                                process_id, facility, rfc5424, address)
    return result


def PySyslogWriter_create_with_tcp_socket(int buffer_size, const char* host_name, const char* application_name,
                                          const char* process_id, int facility, bool rfc5424,
                                          const char* address, int port):
    result = PySyslogWriter(buffer_size)
    result.trace_dump = SyslogTraceDump_create_with_tcp_socket(result.ring_buffer, host_name, application_name,
                                                               process_id, facility, rfc5424, address, port)
    return result
