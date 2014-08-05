#ifndef __trace_message_ring_buffer_h__
#define __trace_message_ring_buffer_h__

#include <cstring>
#include <mintomic/mintomic.h>

#include "trace_message.h"

class atomic_flag {
public:
    atomic_flag() {
        mint_store_32_relaxed(&flag, 0);
    }

    bool test_and_set() {
        if (mint_compare_exchange_strong_32_relaxed(&flag, 0, 1) == 0) {
            return true;
        }
        return false;
    }

    bool test() {
        return mint_load_32_relaxed(&flag) == 1;
    }

    void clear() {
        mint_store_32_relaxed(&flag, 0);
    }
private:
    mint_atomic32_t flag;
};

class atomic_uint32 {
public:
    atomic_uint32(uint32_t _val=0) {
        mint_store_32_relaxed(&val, _val);
    }

    uint32_t inc() {
        return mint_fetch_add_32_relaxed(&val, 1);
    }

    uint32_t operator&=(uint32_t _val) {
        return mint_fetch_and_32_relaxed(&val, _val);
    }

    uint32_t load() const {
        return mint_load_32_relaxed(const_cast<mint_atomic32_t*>(&val));
    }

    void store(uint32_t _val) {
        mint_store_32_relaxed(&val, _val);
    }

private:
    mint_atomic32_t val;
};

class atomic_uint64 {
public:
    atomic_uint64(uint64_t _val=0) {
        mint_store_64_relaxed(&val, _val);
    }

    uint64_t inc() {
        return mint_fetch_add_64_relaxed(&val, 1);
    }

    uint64_t operator&=(uint64_t _val) {
        return mint_fetch_and_64_relaxed(&val, _val);
    }

    uint64_t load() const {
        return mint_load_64_relaxed(const_cast<mint_atomic64_t*>(&val));
    }

    void store(uint64_t _val) {
        mint_store_64_relaxed(&val, _val);
    }
private:
    mint_atomic64_t val;
};

#if MINT_PTR_SIZE == 4
typedef atomic_uint32 atomic_uint;
#else
typedef atomic_uint64 atomic_uint;
#endif

// This is a multi-producer, single-consumer lock-free* ring buffer, where producers in this case are (real) threads
// and the consumer is the trace dump thread.
//
// *lockfree: as in no mutexes, but with spinlocks (not wait-free)
//
// It's tailored to be used as a trace ring buffer with the following properties:
// 1. It allocates all trace message buffers on creation so no memory allocations are be made while tracing.
// 2. It gracefully handles overruns - the producers will overrun existing messages so when the consumer is ready
//    it will write new messages and not old ones. To guarantee that a slow consumer won't slow down the program
//    a lock is kept only for copying the message to a consumer-internal buffer which should be (relatively) fast.
// 3. It saves some memory copying operations by allowing the producers to "reserve" a slot in the buffer and then
//    "commit" it, thereby doing all the formatting on the buffer itself.
//
// CAVEATS/NOTES:
//
// - Queue size must be a power of 2 (simply because we use std's atomic &= operator).
// - We don't support a use case where the combination of number of producers and the time it takes to each producer
//   to commit a message is so long that the producers lock all messages in the queue. By "not supporting" we mean that
//   performance will suffer. Greatly suffer. So don't do that.
//
// HOW IT WORKS:
//
// From the producer's side -
//
// Every time a producer wants to reserve a message buffer it increments an atomic head pointer, so no contention here
// between producers trying to find a free slot (see caveat above on when this assumption fails).
//
// Now the producer has found a slot that _should_ be free. It should be but not necessarily not because maybe the
// consumer is currently copying data from it (or in worst case scenario another producer is holding it - but we're not
// going to discuss this anymore because it shouldn't happen if you have a queue large enough).
//
// To keep a lock on each slot we use a busy flag per message (std's atomic flag) which we use as a spin lock.
// The producer waits to acquire it. This wait shouldn't take long because if the lock is held it's only held by the
// buffer copy operation the consumer is doing, and this will only happen if the consumer is so slow that overruns
// start to happen.
//
// Once the lock is held the producer is free to write to the message buffer and when it's done it releases the lock.
//
// From the consumner's side -
//
// The consumer keeps a tail pointer. Whenever it tries to fetch a message it first locks the message - this may take
// some time if the producer is currently writing to it (see TODO). After it locks the message it needs to see if the
// slot is filled or not (if the consumer is fast enough it may arrive to a slot that's not been used by a producer).
//
// To check if a slot is free or occupied we have a "has data" flag (std's atomic flag). If the flag is set it means
// that the slot has data. The _producer_ sets it on reserve, and the consumer checks it when fetching a message -
// if it's clear it keeps it clear and returns false.
//
// Checking for overruns (overflows) -
//
// We use the same "has data" flag to test for overruns. If the producer locks a slot and then sees that the "has data"
// flag is set, it means that the consumer didn't get to that slot which means that an overrun occurred.
//
// TODO revisit memroy allocation strategy to avoid copying memory altogether (allocate batches of buffers, etc.)
// TODO when the consumer waits on an occupied lock it does a busy loop - we may want to change the API return value
//      to return three options: "copied data", "no data found", "busy" so a different sleep time can be used by the
//      consumer thread.
class TraceMessageRingBuffer {
public:
    TraceMessageRingBuffer(size_t _capacity, size_t _trace_message_capacity) :
        capacity(_capacity),
        trace_message_capacity(_trace_message_capacity),
        elements(new TraceMessage[_capacity]),
        busy(new atomic_flag[_capacity]),
        has_data(new atomic_flag[_capacity]),
        head(0),
        tail(0),
        overflow_counter(0),
        resettable_overflow_counter(0),
        spinlock_consumer_wait_counter(0),
        spinlock_producer_wait_counter(0) {
        //BOOST_VERIFY(capacity > 1 && !(capacity & (capacity - 1)));  // make sure buffer size is a power of 2
        for (size_t i = 0; i < capacity; ++i) {
            elements[i].realloc(trace_message_capacity);
            busy[i].clear();
            has_data[i].clear();
        }
    }

    ~TraceMessageRingBuffer() {
        delete[] elements;
        delete[] busy;
        delete[] has_data;
    }

    // Returns an empty slot that the producer can write to. When the producer is finished writing it calls commit_push
    // with the same pointer it received here.
    TraceMessage* reserve_push() {
        size_t reserved_space = static_cast<size_t>(head.inc());

        // We want to keep the indexes inside 0..capacity-1 range.
        if (reserved_space >= capacity) {
            // prevent counter overflow - queue size must be a power of 2.
            head &= capacity - 1;
            reserved_space &= capacity - 1;
        }

        TraceMessage* elem = &elements[reserved_space];

        // We assume not all producers managed to write to the entire buffer and wrap around to this space otherwise
        // we're shooting ourselves in the leg (see caveat).
        lock_element(reserved_space, spinlock_producer_wait_counter);

        // Check for overruns - if the slot has data it means the consumer didn't get to it which means an overrun
        // occurred.
        if (!has_data[reserved_space].test_and_set()) {
            overflow_counter.inc();
            resettable_overflow_counter.inc();
        }

        return elem;
    }

    void commit_push(TraceMessage* element) {
        unlock_element(element - elements);
    }

    // Pops a message from the queue and copies it to the buffer. Returns true if a message was copied and false there
    // was no message to copy.
    bool pop(TraceMessage& message) {
        int i = tail;

        if (!has_data[i].test()) {
            return false;
        }

        lock_element(i, spinlock_consumer_wait_counter);

        bool has_data_for_element = has_data[i].test();
        if (has_data_for_element) {
            tail = (tail + 1) & (capacity - 1);
            message = elements[i];

            elements[i].recycle();
            has_data[i].clear();
        }

        unlock_element(i);
        return has_data_for_element;
    }

    unsigned long get_overflow_counter() const { return overflow_counter.load(); }

    unsigned long get_and_reset_overflow_counter() {
        unsigned long r = resettable_overflow_counter.load();
        resettable_overflow_counter.store(0);
        return r;
    }

    unsigned long get_spinlock_consumer_wait_counter() const { return spinlock_consumer_wait_counter.load(); }

    unsigned long get_spinlock_producer_wait_counter() const { return spinlock_producer_wait_counter.load(); }

    size_t get_capacity() const { return capacity; }

    size_t get_trace_message_capacity() const { return trace_message_capacity; }

private:
    inline void lock_element(int i, atomic_uint64& counter) {
        bool collision = false;
        while (!busy[i].test_and_set()) {
            collision = true;
        }
        if (collision) {
            counter.inc();
        }
    }

    inline void unlock_element(int i) {
        busy[i].clear();
    }

    size_t capacity;
    size_t trace_message_capacity;
    TraceMessage* elements;
    atomic_flag* busy;
    atomic_flag* has_data;

    atomic_uint head;
    int tail;   // no need to make this atomic since we've got only one consumer.

    atomic_uint64 overflow_counter;
    atomic_uint64 resettable_overflow_counter;
    atomic_uint64 spinlock_consumer_wait_counter;
    atomic_uint64 spinlock_producer_wait_counter;
};

#endif