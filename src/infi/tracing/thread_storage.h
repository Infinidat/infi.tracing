#ifndef __thread_storage_h
#define __thread_storage_h

#include <unordered_map>

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
	ThreadStorage() : enabled(true), last_frame(0), last_gid(-1), gid_map() {}

	bool enabled;
	long last_frame;
	long last_gid;

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
		}
	}

protected:
	typedef std::unordered_map<long, GreenletStorage> GIDMap;
	GIDMap gid_map;

private:
	ThreadStorage(const ThreadStorage&) = delete;
	ThreadStorage& operator=(const ThreadStorage&) = delete;
};

extern ThreadStorage* get_thread_storage();

#endif /* __thread_storage_h */