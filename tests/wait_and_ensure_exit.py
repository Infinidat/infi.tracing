from infi.tracing import wait_and_ensure_exit
from time import sleep


print("waiting 5 seconds before exitting.")
wait_and_ensure_exit(5, 1)
for i in range(10):
    print("doing stuff... should die soon.")
    sleep(1)
print("failed.")
