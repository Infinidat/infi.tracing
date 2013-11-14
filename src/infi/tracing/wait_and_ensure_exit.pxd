cdef extern from "wait_and_ensure_exit.h":
    cdef cppclass WaitAndEnsureExit:
        WaitAndEnsureExit() nogil  # Cython limitation - see http://trac.cython.org/cython_trac/ticket/687
        void go(int seconds, int exit_code) nogil
