#ifndef __thread_storage_h
#define __thread_storage_h

#define NESTED_NO_TRACE_DISABLED -314159  // Python's stack cannot be that big anyhow.

class ThreadStorage {
public:
	long depth;
	long nested_no_trace_depth;
	bool enabled;

	ThreadStorage() : depth(-1), nested_no_trace_depth(NESTED_NO_TRACE_DISABLED), enabled(true) {}
	
	ThreadStorage(const ThreadStorage& o) : depth(o.depth), nested_no_trace_depth(o.nested_no_trace_depth), 
							   			    enabled(o.enabled) {}

	ThreadStorage& operator=(const ThreadStorage& o) {
		depth = o.depth;
		nested_no_trace_depth = o.nested_no_trace_depth;
		enabled = o.enabled;
		return *this;
	}
};

#endif /* __thread_storage_h */