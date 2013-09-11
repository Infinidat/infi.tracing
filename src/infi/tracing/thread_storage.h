#ifndef __thread_storage_h
#define __thread_storage_h

#include <boost/unordered_map.hpp>

#define NO_TRACE_FROM_DEPTH_DISABLED 314159  // Python's stack cannot be that big anyhow.

class GreenletStorage {
public:
	long gid;
	long depth;
	long no_trace_from_depth;
	long last_frame;
	bool enabled;

	GreenletStorage() : gid(-1), depth(-1), no_trace_from_depth(NO_TRACE_FROM_DEPTH_DISABLED), last_frame(0), 
					    enabled(true) {}

	GreenletStorage(const GreenletStorage& o) : gid(o.gid), depth(o.depth), no_trace_from_depth(o.no_trace_from_depth), 
												last_frame(o.last_frame), enabled(o.enabled) {}

	GreenletStorage& operator=(const GreenletStorage& o) {
		gid = o.gid;
		depth = o.depth;
		no_trace_from_depth = o.no_trace_from_depth;
		last_frame = o.last_frame;
		enabled = o.enabled;
		return *this;
	}
};

class ThreadStorage {
public:
	ThreadStorage() : enabled(1), last_frame(0), last_gid(-1), last_gstorage(0), gid_map() {
		gid_map.reserve(32);
	}

	int enabled;
	long last_frame;
	long last_gid;
	GreenletStorage* last_gstorage;

	GreenletStorage* find_gstorage(long gid) {
		GIDMap::iterator i = gid_map.find(gid);
		if (i != gid_map.end()) {
			return &(i->second);
		}
		return 0;
	}

	GreenletStorage* new_gstorage(long gid) {
		GreenletStorage* result = &gid_map[gid];
		result->gid = gid;
		return result;
	}

	void del_gstorage(long gid) {
		gid_map.erase(gid);
		if (last_gid == gid) {
			last_gid = -1;
			last_frame = 0;
			last_gstorage = 0;
		}
	}

protected:
	typedef boost::unordered_map<long, GreenletStorage> GIDMap;
	GIDMap gid_map;

private:
	// Supporting old compilers - no c++11 for us:
	// ThreadStorage(const ThreadStorage&) = delete;
	// ThreadStorage& operator=(const ThreadStorage&) = delete;
};

extern void init_thread_storage_once();
extern ThreadStorage* get_thread_storage();

#endif /* __thread_storage_h */