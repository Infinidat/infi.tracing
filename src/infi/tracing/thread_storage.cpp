#include "thread_storage.h"
#include <pthread.h>
#include <stdio.h>

static pthread_key_t storage_key;
static pthread_once_t storage_key_once = PTHREAD_ONCE_INIT;

void del_thread_storage(void* ptr) {
	delete (ThreadStorage*) ptr;
}

void init_thread_storage() {
	// TODO: move this code to Cython so we can use Python's loggger to write an error if this fails.
 	if (pthread_key_create(&storage_key, del_thread_storage) != 0) {
 		fprintf(stderr, "infi.tracing: failed to create per-thread storage\n");
		return;
	}
}

void init_thread_storage_once() {
	(void) pthread_once(&storage_key_once, init_thread_storage);
}

ThreadStorage* get_thread_storage() {
	// To save some cycles we moved the pthread_once(...) call to a new function that is called whenever setting a
	// trace.
	void* ptr = pthread_getspecific(storage_key);
	pthread_t id = pthread_self();
	if (ptr == NULL) {
		ptr = (void*)new ThreadStorage(static_cast<unsigned long>(id));
		(void) pthread_setspecific(storage_key, ptr);
	}
	return (ThreadStorage*) ptr;
}
