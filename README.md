Tracing mechanism for Python on POSIX systems
=============================================

A module tracing function calls with as less performnce penalty as possible.

This module provides:
* hooks for `sys.gettrace` written in Cython that that extract information about the function call without taking the GIL and put it in a cyclic buffe.r
* spawns a POSIX thrads that reads from the cyclic buffers and dumps to either stdout, stderr or syslog, preferrably over TCP


Usage
-----


    from infi.tracing import *
    tracing_output_to_syslog(...) # or to stderr, or stdout
    set_tracing() # by default, traces all functions; you can pass a filter function that accepts a frame and returns True or False

    with exclude_from_traces_context():
        pass # to enclude all tracing inside while inside the context

    @exclude_from_traces_recursive
    def func():
        pass # don't trace while out of the stack

Caveats
-------
* Current method uses an LRU cache that maps between a code object address (frame.f_code) to a trace level decision
  (to trace or not to trace, etc.).
  This is theoretically broken, since a code object might get freed and a new code object will get allocated on the
  exact same address, leading us to think that we already have a trace decision for that code object when in fact we
  don't.
  After discussing it with Rotem, it appears that code objects will not get deallocated except if the code uses "eval",
  which for 99% of the code (and ours in particular) this is not the case so we don't need to worry about it.
* We don't support tuple arguments, but then again Python 3 won't support them either (PEP 3113).


Benchmarks and expectations
---------------------------

All benchmarks were done on the following setup:
- Ubuntu 12.10 x64
- Python 2.7.2
- 2 i7 L640 CPUs 2.13GHz
- 6GB RAM
- Transcend 128GB SSD

Running benchmark_test.py (5 seconds per iter, 5 iters)
-------------------------------------------------------

commit 10df3efec12393cb7621aa99b24b82eca0840f3f
  baseline: 1825720.00, 1835449.80, 1842398.00, 1830729.20, 1833467.40 min/avg d -0.43% max/avg d  0.48%
  test    : 1633125.40, 1635413.40, 1628644.00, 1606401.20, 1633005.20 min/avg d -1.29% max/avg d  0.50% (1.13 times slower than baseline)

  - return 0 immediately when entering our greenlet_trace_func function.
  - 13% slower than no trace at all.

commit 193804b3304cbc3cde06090b61a19ffdd454258f
  baseline: 1819488.00, 1833624.00, 1839292.20, 1833125.00, 1816866.80 min/avg d -0.64% max/avg d  0.59%
  test    :  905229.00,  908321.20,  904548.20,  905278.20,  902933.00 min/avg d -0.26% max/avg d  0.34% (2.02 times slower than baseline)

  - do greenlet and LRU filter lookup/call but nothing more.
  - ~100% slower than baseline (+87% from null tracing).

commit 9d27a55296f7efeb8b1641db9c8bd269609aad96
  baseline: 1845614.20, 1838952.00, 1848122.80, 1825571.20, 1835942.80 min/avg d -0.72% max/avg d  0.50%
  test    : 1503825.00, 1496979.60, 1505625.80, 1503810.80, 1504720.00 min/avg d -0.40% max/avg d  0.18% (1.22 times slower than baseline)

 - just fetch thread-local storage and nothing more.
 - ~20% slower than baseline (+7% from null tracing).

commit ff8b7994c3cd773f3484fd99a406d74c07b80afb
  baseline: 1814547.00, 1833100.00, 1859893.40, 1834792.80, 1793069.00 min/avg d -1.86% max/avg d  1.80%
  test    :  987167.80,  991204.80,  993721.40,  998788.40, 1000324.20 min/avg d -0.71% max/avg d  0.61% (1.84 times slower than baseline)

  - fetch thread-local storage and gstore. No LRU search.
  - ~80% slower than baseline (+67% from null tracing).


Checking out the code
=====================

Run the following:

    easy_install -U infi.projector
    projector devenv build
