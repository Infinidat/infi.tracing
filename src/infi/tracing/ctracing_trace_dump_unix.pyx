from trace_dump cimport SyslogTraceDump, SyslogSocket, SyslogUNIXSocket, SyslogTCPSocket

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
