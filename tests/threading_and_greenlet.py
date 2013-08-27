import threading
import greenlet

class MyThread(threading.Thread):
    def run(self):
        print("tid={}, gid={}".format(self.ident, greenlet.getcurrent()))

threads = [MyThread() for i in range(2)]

for thread in threads:
    thread.start()

for thread in threads:
    thread.join()