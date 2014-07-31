#ifndef __thread_storage_h
#define __thread_storage_h

#include <vector>
#include "uthash.h"

#define NO_TRACE_FROM_DEPTH_DISABLED 314159  // Python's stack cannot be that big anyhow.

class GreenletStorage {
public:
	long gid;
	long depth;
	long no_trace_from_depth;
	long last_frame;
	bool enabled;
	UT_hash_handle hh;

	GreenletStorage(long _gid) : gid(_gid), depth(-1), no_trace_from_depth(NO_TRACE_FROM_DEPTH_DISABLED), last_frame(0),
					    		 enabled(true) {}

private:
	GreenletStorage(const GreenletStorage& o);
	GreenletStorage& operator=(const GreenletStorage& o);
};

class ThreadStorage {
public:
	ThreadStorage(unsigned long _id) : id(_id), enabled(1), last_frame(0), last_gid(-1), last_gstorage(0),
									   gid_map(NULL) {
	}

	unsigned long id;
	int enabled;
	long last_frame;
	long last_gid;
	GreenletStorage* last_gstorage;

	GreenletStorage* find_gstorage(long gid) {
		GreenletStorage* result;
		HASH_FIND_INT(gid_map, &gid, result);
		return result;
	}

	GreenletStorage* new_gstorage(long gid) {
		GreenletStorage* result = new GreenletStorage(gid);
		HASH_ADD_INT(gid_map, gid, result);
		return result;
	}

	void del_gstorage(GreenletStorage* ptr) {
		HASH_DEL(gid_map, ptr);
		delete ptr;
	}

protected:
	GreenletStorage* gid_map;

private:
	ThreadStorage(const ThreadStorage&);
	ThreadStorage& operator=(const ThreadStorage&);
};

extern void init_thread_storage_once();
extern ThreadStorage* get_thread_storage();

#endif /* __thread_storage_h */