import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from utils import add_infi_tracing_to_sys_path
add_infi_tracing_to_sys_path()


from infi.tracing import set_tracing, unset_tracing, TRACE_FUNC_NAME
from greenlet import getcurrent, greenlet


def g1_bar():
    print("g1_bar")


def g1_foo():
    print("g1_foo")
    getcurrent().parent.switch()
    g1_bar()


def g2_bar():
    print("g2_bar")


def g2_foo():
    print("g2_foo")
    getcurrent().parent.switch()
    g2_bar()


def g3_foo():
    print("g3_foo")
    getcurrent().parent.switch()


# Test if GreenletExit (when killing a greenlet) traverses entire stack.
def k3():
    print("k3")
    getcurrent().parent.switch()


def k2():
    print("k2")
    k3()


def k1():
    print("k1")
    k2()


def trace_filter(frame):
    return TRACE_FUNC_NAME


set_tracing(trace_filter)

g1 = greenlet(g1_foo)
g2 = greenlet(g2_foo)
g3 = greenlet(g3_foo)
print("switching to g1")
g1.switch()
print("switching to g2")
g2.switch()
print("switching to g3")
g3.switch()

not_dead = True
while not_dead:
    not_dead = False
    for g in [g1, g2, g3]:
        if not g.dead:
            not_dead = True
            g.switch()

k = greenlet(k1)
k.switch()
print("killing k")
k.throw()

unset_tracing()
print("done.")
