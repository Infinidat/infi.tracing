#ifndef __trace_message_ring_buffer_h__
#define __trace_message_ring_buffer_h__

#include <stdio.h> // debug
#include <mutex>
#include <condition_variable>

#include "trace_message.h"

#define RING_BUFFER_SIZE (64 * 1024)  // ~64MB

// Multi-producer, single-consumer ring buffer.
class TraceMessageRingBuffer {
public:
	TraceMessageRingBuffer() : 
		elements(), size(0),
		reserve_head(0), ready_head(0),
		reserve_tail(0), ready_tail(0),
		shutdown(false), mutex(), cond(), overflow_counter(0) {
		for (int i = 0; i < RING_BUFFER_SIZE; ++i) {
			elements[i].recycle();
		}
	}

	TraceMessage* reserve_push() {
		// TODO: we're not handling a situation where there are many reservations that fill the queue.
		LockGuard guard(mutex);

		TraceMessage* result = &elements[reserve_head];
		reserve_head = (reserve_head + 1) % RING_BUFFER_SIZE;

		if (i_is_full()) {
			// We're overwriting a previous message.
			reserve_tail = (reserve_tail + 1) % RING_BUFFER_SIZE;
			overflow_counter++;
		} else {
			size++;
		}
		return result;
	}

	void commit_push(TraceMessage* element) {
		int i = element - elements;
		bool wakeup = false;
		{
			LockGuard guard(mutex);
			element->set_ready();
			if (ready_head == i) {
				wakeup = true;
				while (elements[ready_head].is_ready() && (ready_head != reserve_head)) {
					ready_head = (ready_head + 1) % RING_BUFFER_SIZE;
				}
			}
		}

		if (wakeup) {
			cond.notify_one();
		}
	}

	TraceMessage* reserve_pop(long timeout_in_millis=0) {
		UniqueLock lk(mutex);
		if (timeout_in_millis == 0) {  // non-blocking
			if (!i_is_ready_avail()) {
				lk.unlock();
				return 0;
			}
		} else if (timeout_in_millis < 0) {  // block forever
			cond.wait(lk, [this]() { return i_is_ready_avail(); });
		} else {  // block w/ timeout
			if (!cond.wait_for(lk, std::chrono::milliseconds(timeout_in_millis),
							   [this]() { return i_is_ready_avail(); })) {
				lk.unlock();
				return 0;
			}
		}

		TraceMessage* result = &elements[reserve_tail];
		reserve_tail = (reserve_tail + 1) % RING_BUFFER_SIZE;

		lk.unlock();
		return result;
	}

	void commit_pop() {
		LockGuard guard(mutex);
		elements[ready_tail].recycle();
		ready_tail = (ready_tail + 1) % RING_BUFFER_SIZE;
		size--;
	}

	unsigned long get_overflow_counter() const {
		return overflow_counter;
	}

protected:
	bool i_is_full() const {
		return size == RING_BUFFER_SIZE;
	}

	bool i_is_empty() const {
		return size == 0;
	}

	bool i_is_ready_avail() const {
		return !i_is_ready_empty();
	}

	bool i_is_ready_empty() const {
		return i_is_empty() || (reserve_tail == ready_head);
	}

private:
	typedef std::lock_guard<std::mutex> LockGuard;
	typedef std::unique_lock<std::mutex> UniqueLock;

	TraceMessage elements[RING_BUFFER_SIZE];
	int size;
	int reserve_head;
	int ready_head;
	int reserve_tail;
	int ready_tail;
	bool shutdown;

	std::mutex mutex;
	std::condition_variable cond;

	unsigned long overflow_counter;
};

#endif