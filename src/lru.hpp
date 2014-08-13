#ifndef __lru_hpp__
#define __lru_hpp__

#include <uthash.h>

#define LRU_NOT_FOUND (-1)


class LRU {
public:
	typedef unsigned long key;
	typedef int value;

	LRU(size_t _capacity) :
		capacity(_capacity),
		hash_handle(NULL),
		entries(new entry[_capacity]) {
	}

	~LRU() {
		// We have to iterate the entire hash table and "delete" each element so uthash will delete all its internal
		// records when we delete the "final" entry.
		entry_ptr entry = NULL;
		entry_ptr tmp_entry = NULL;
		HASH_ITER(hh, hash_handle, entry, tmp_entry) {
			HASH_DEL(hash_handle, entry);
		}
		delete[] entries;
	}

	void insert(key k, value v) {
		size_t used_size = HASH_COUNT(hash_handle);
		entry_ptr entry = NULL;
		entry_ptr tmp_entry = NULL;

		if (used_size >= capacity) {
			HASH_ITER(hh, hash_handle, entry, tmp_entry) {
				HASH_DEL(hash_handle, entry);
				break;
			}
		} else {
			// Since we don't support the delete operation it makes it easy for us to choose a vacant entry - it will
			// be the next available entry in the array. Once the array gets filled this branch will never get executed.
			entry = &entries[used_size];
		}

		entry->k = k;
		entry->v = v;
		HASH_ADD_INT(hash_handle, k, entry);
	}

	value find(key k) {
		entry* elem = NULL;
		HASH_FIND_INT(hash_handle, &k, elem);
		if (elem == NULL) {
			return LRU_NOT_FOUND;
		}
		// Re-insert the element back to the hash so it'll be the most recently used.
		HASH_DEL(hash_handle, elem);
		HASH_ADD_INT(hash_handle, k, elem);
		return elem->v;
	}

private:
	typedef struct _entry {
		key k;
		value v;
		UT_hash_handle hh;
	} entry;
	typedef entry* entry_ptr;

	size_t capacity;
	entry_ptr hash_handle;
	entry_ptr entries;
};

#endif // __lru_hpp__