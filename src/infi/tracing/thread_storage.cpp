#include "thread_storage.h"
#include <pthread.h>

static pthread_key_t storage_key;
static pthread_once_t storage_key_once = PTHREAD_ONCE_INIT;

void del_thread_storage(void* ptr) {
	delete (ThreadStorage*) ptr;
}

void init_thread_storage() {
 	if (pthread_key_create(&storage_key, del_thread_storage) != 0) {
 		// FIXME: show this error.
		return;
	}
}

ThreadStorage* get_thread_storage() {
	(void) pthread_once(&storage_key_once, init_thread_storage);

	void* ptr = pthread_getspecific(storage_key);
	if (ptr == NULL) {
		ptr = (void*)new ThreadStorage();
		(void) pthread_setspecific(storage_key, ptr);
	}
	return (ThreadStorage*) ptr;
}
