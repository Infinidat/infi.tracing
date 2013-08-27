#ifndef __trace_message_ring_buffer_h__
#define __trace_message_ring_buffer_h__

#include <stdio.h> // debug
#include <mutex>
#include <condition_variable>
#include <cstring>
#include <atomic>

#include "trace_message.h"

#define RING_BUFFER_SIZE (65536)  // 64K messages = ~64MB, queue size must be a power of 2.

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
// TODO move buffer allocation to constructor as argument
// TODO revisit memroy allocation strategy to avoid copying memory altogether (allocate batches of buffers, etc.)
// TODO mark on a trace message if there was an overrun and pass it to the consumer so it can log it
// TODO when the consumer waits on an occupied lock it does a busy loop - we may want to change the API return value
//      to return three options: "copied data", "no data found", "busy" so a different sleep time can be used by the
//      consumer thread.
class TraceMessageRingBuffer {
public:
    TraceMessageRingBuffer() : 
        elements(), busy(), has_data(), head(0), tail(0), overflow_counter(0), spinlock_consumer_wait_counter(0),
        spinlock_producer_wait_counter(0) {
        for (int i = 0; i < RING_BUFFER_SIZE; ++i) {
            elements[i].recycle();
            busy[i].clear();
            has_data[i].clear();
        }
    }

    // Returns an empty slot that the producer can write to. When the producer is finished writing it calls commit_push
    // with the same pointer it received here.
    TraceMessage* reserve_push() {       
        int reserved_space = head++;  // using std's atomic operator++

        // We want to keep the indexes inside 0..RING_BUFFER_SIZE-1 range.
        if (reserved_space >= RING_BUFFER_SIZE) {
            // prevent counter overflow - queue size must be a power of 2.
            head &= RING_BUFFER_SIZE - 1;
            reserved_space &= RING_BUFFER_SIZE - 1;
        }

        TraceMessage* elem = &elements[reserved_space];

        // We assume not all producers managed to write to the entire buffer and wrap around to this space otherwise
        // we're shooting ourselves in the leg (see caveat).
        lock_element(reserved_space, spinlock_consumer_wait_counter);

        // Check for overruns - if the slot has data it means the consumer didn't get to it which means an overrun
        // occurred.
        if (has_data[reserved_space].test_and_set()) {
            overflow_counter++;
        }

        return elem;
    }

    void commit_push(TraceMessage* element) {
        busy[element - elements].clear();
    }

    // Pops a message from the queue and copies it to the buffer. Returns true if a message was copied and false there
    // was no message to copy.
    bool pop(char* buffer, int maxsize) {
        int i = tail;

        lock_element(i, spinlock_producer_wait_counter);

        if (!has_data[i].test_and_set()) {
            has_data[i].clear();
            busy[i].clear();
            return false;
        } else {
            tail = (tail + 1) & (RING_BUFFER_SIZE - 1);
        }

        std::strncpy(buffer, elements[i].get_buffer(), maxsize);

        elements[i].recycle();
        has_data[i].clear();
        busy[i].clear();

        return true;
    }

    unsigned long get_overflow_counter() const { return overflow_counter.load(); }

    unsigned long get_spinlock_consumer_wait_counter() const { return spinlock_consumer_wait_counter.load(); }

    unsigned long get_spinlock_producer_wait_counter() const { return spinlock_producer_wait_counter.load(); }

private:
    inline void lock_element(int i, std::atomic_ulong& counter) {
        bool collision = false;
        while (busy[i].test_and_set()) {
            collision = true;
        }
        if (collision) {
            counter++;
        }
    }

    TraceMessage elements[RING_BUFFER_SIZE];
    std::atomic_flag busy[RING_BUFFER_SIZE];
    std::atomic_flag has_data[RING_BUFFER_SIZE];

    std::atomic_int head;
    int tail;   // no need to make this atomic since we've got only one consumer.

    std::atomic_ulong overflow_counter;
    std::atomic_ulong spinlock_consumer_wait_counter;
    std::atomic_ulong spinlock_producer_wait_counter;
};

#endif