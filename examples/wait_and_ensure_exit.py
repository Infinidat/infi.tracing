import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from utils import add_infi_tracing_to_sys_path
add_infi_tracing_to_sys_path()


from infi.tracing import wait_and_ensure_exit
from time import sleep


print("waiting 5 seconds before exitting.")
wait_and_ensure_exit(5, 1)
for i in range(10):
    print("doing stuff... should die soon.")
    sleep(1)
print("failed.")
