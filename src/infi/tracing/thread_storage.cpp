#include <stdio.h>
#include <mintomic/mintomic.h>
#include "thread_storage.h"

static size_t trace_level_lru_capacity = 256;

#ifdef MINT_COMPILER_MSVC // WINDOWS
#include <windows.h>

static DWORD storage_key;
static mint_atomic32_t storage_key_once = {0};

void init_thread_storage() {
	storage_key = TlsAlloc();
	if (storage_key == TLS_OUT_OF_INDEXES) {
 		fprintf(stderr, "infi.tracing: failed to create per-thread storage\n");
		return;
	}
}

void init_thread_storage_once(size_t _trace_level_lru_capacity) {
	trace_level_lru_capacity = _trace_level_lru_capacity;
	if (mint_compare_exchange_strong_32_relaxed(&storage_key_once, 0, 1) == 0) {
		init_thread_storage();
	}
}

void del_thread_storage(PVOID ptr, BOOL) {
	delete (ThreadStorage*) ptr;
}

ThreadStorage* get_thread_storage() {
	// To save some cycles we moved the pthread_once(...) call to a new function that is called whenever setting a
	// trace.
	void* ptr = TlsGetValue(storage_key);
	DWORD id = GetCurrentThreadId();
	if (ptr == NULL) {
		ptr = (void*)new ThreadStorage((unsigned long) id, trace_level_lru_capacity);
		(void) TlsSetValue(storage_key, ptr);

		HANDLE t = INVALID_HANDLE_VALUE;
		if (DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(), &t, SYNCHRONIZE, FALSE, 0)) {
			HANDLE wait_h;
			RegisterWaitForSingleObject(&wait_h, t, reinterpret_cast<WAITORTIMERCALLBACK>(&del_thread_storage), ptr,
										INFINITE, WT_EXECUTEDEFAULT | WT_EXECUTEONLYONCE);
		} else {
			// Mem leak on thread exit.
		}

	}
	return (ThreadStorage*) ptr;
}

#else // UNIX

#include <pthread.h>

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

void init_thread_storage_once(size_t _trace_level_lru_capacity) {
	trace_level_lru_capacity = _trace_level_lru_capacity;
	(void) pthread_once(&storage_key_once, init_thread_storage);
}

ThreadStorage* get_thread_storage() {
	// To save some cycles we moved the pthread_once(...) call to a new function that is called whenever setting a
	// trace.
	void* ptr = pthread_getspecific(storage_key);
	pthread_t id = pthread_self();
	if (ptr == NULL) {
		ptr = (void*)new ThreadStorage((unsigned long) id, trace_level_lru_capacity);
		(void) pthread_setspecific(storage_key, ptr);
	}
	return (ThreadStorage*) ptr;
}
#endif