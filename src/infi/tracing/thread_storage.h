#ifndef __thread_storage_h
#define __thread_storage_h

#include <vector>
#include "uthash.h"
#include "lru.hpp"

#define NO_TRACE_FROM_DEPTH_DISABLED 314159  // Python's stack cannot be that big anyhow.

class GreenletStorage {
public:
	long gid;
	long depth;
	long no_trace_from_depth;
	long last_frame;
	bool enabled;
	LRU trace_level_lru;
	UT_hash_handle hh;

	GreenletStorage(long _gid, size_t trace_level_lru_capacity):
		gid(_gid),
		depth(-1),
		no_trace_from_depth(NO_TRACE_FROM_DEPTH_DISABLED),
		last_frame(0),
		enabled(true),
		trace_level_lru(trace_level_lru_capacity) {}


private:
	GreenletStorage(const GreenletStorage& o);
	GreenletStorage& operator=(const GreenletStorage& o);
};

class ThreadStorage {
public:
	ThreadStorage(unsigned long _id, size_t _trace_level_lru_capacity):
		id(_id),
		enabled(1),
		last_frame(0),
		last_gid(-1),
		last_gstorage(0),
		gid_map(NULL),
		trace_level_lru_capacity(_trace_level_lru_capacity) {
	}

	~ThreadStorage() {
		GreenletStorage* entry;
		GreenletStorage* tmp;
		HASH_ITER(hh, gid_map, entry, tmp) {
			HASH_DEL(gid_map, entry);
			delete entry;
		}
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
		GreenletStorage* result = new GreenletStorage(gid, trace_level_lru_capacity);
		HASH_ADD_INT(gid_map, gid, result);
		return result;
	}

	void del_gstorage(GreenletStorage* ptr) {
		HASH_DEL(gid_map, ptr);
		delete ptr;
	}

protected:
	GreenletStorage* gid_map;
	size_t trace_level_lru_capacity;

private:
	ThreadStorage(const ThreadStorage&);
	ThreadStorage& operator=(const ThreadStorage&);
};

extern void init_thread_storage_once(size_t _trace_level_lru_capacity);
extern ThreadStorage* get_thread_storage();

#endif /* __thread_storage_h */