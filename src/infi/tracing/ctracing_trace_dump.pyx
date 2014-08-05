from trace_dump cimport TraceDump, FileTraceDump
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


IF UNAME_SYSNAME != "Windows":
    include "ctracing_trace_dump_unix.pyx"
