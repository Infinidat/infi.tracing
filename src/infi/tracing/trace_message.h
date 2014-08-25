#ifndef __trace_message_h__
#define __trace_message_h__

#include <stdarg.h>
#include <stdio.h>
#include <algorithm>
#include <cstring>
#include <mintomic/platform_detect.h>

#ifdef MINT_COMPILER_MSVC
#define NOMINMAX
#include <windows.h>
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#else
#include <stdint.h>
#include <sys/time.h>
#endif

#define SEVERITY_NOTSET (-1)

template <typename T>
T clip(const T& n, const T& lower, const T& upper) {
  return std::max(lower, std::min(n, upper));
}

class TraceMessage {
public:
	TraceMessage(int _capacity=0):
		capacity(0), buffer(const_cast<char*>("")), write_index(0), limit_index(0), severity(SEVERITY_NOTSET),
		timestamp() {
		if (_capacity > 0) {
			realloc(_capacity);
		}
	}

	~TraceMessage() {
		if (capacity > 0) {
			delete[] buffer;
		}
	}

	void operator=(const TraceMessage& other) {
		if (other.capacity != capacity) {
			realloc(other.capacity);
		}
		write_index = other.write_index;
		limit_index = other.limit_index;
		severity = other.severity;
		timestamp = other.timestamp;
		std::strncpy(buffer, other.buffer, capacity);
	}

	void recycle() {
		write_index = 0;
		limit_index = capacity;
		buffer[0] = buffer[capacity] = '\0';
		severity = SEVERITY_NOTSET;
		timestamp = 0;
	}

	void realloc(int new_capacity) {
		if (capacity > 0) {
			delete[] buffer;
		}
		if (new_capacity > 0) {
			capacity = new_capacity;
			buffer = new char[capacity + 1];
		}
		recycle();
	}

	const char* get_buffer() const { return buffer; }

	int write_offset() const { return write_index; }

	int max_size() const { return limit_index; }

	int avail_size() const { return limit_index - write_index; }

	int limit(int size) {
		int prev_limit_index = limit_index;
		limit_index = write_index + clip(size, 0, avail_size());
		return prev_limit_index;
	}

	void unlimit() {
		limit_index = capacity;
	}

	void unlimit(int i) {
		limit_index = clip(i, 0, capacity);
	}

	void rewind(int offset) {
		write_index = clip(offset, 0, limit_index);
		buffer[write_index] = '\0';
	}

	bool write(const char* str) {
		while (write_index < limit_index) {
			buffer[write_index] = *str;
			if (*str == '\0') {
				return true;
			}
			write_index++;
			str++;
		}
		return false;
	}

	bool printf(const char* fmt, ...) {
		va_list ap;
		va_start(ap, fmt);
		bool result = vnprintf(avail_size(), fmt, ap);
		va_end(ap);
		return result;
	}

	bool nprintf(int max_size, const char* fmt, ...) {
		va_list ap;
		va_start(ap, fmt);
		bool result = vnprintf(max_size, fmt, ap);
		va_end(ap);
		return result;
	}

	bool vnprintf(int max_size, const char* fmt, va_list ap) {
		int n = vsnprintf(&buffer[write_index], std::min(avail_size(), max_size), fmt, ap);
		if (n > -1 && n <= avail_size()) {
			write_index += n;
			return true;
		} else {
			// failed to write everything, so we write nothing.
			buffer[write_index] = '\0';
			return false;
		}
	}

	void set_timestamp() {
#ifdef MINT_COMPILER_MSVC
		FILETIME ft;
		GetSystemTimeAsFileTime(&ft);
		// We do several things here:
		// 1. convert the windows struct to uint64_t
		// 2. make the result in microseconds and not 100 nanos
		// 3. GetSystemTimeAsFileTime returns the 100 nanos since 01/01/1601. We need Epoch (01/01/1970).
		// 4. We subtract 11644473600000000, which is the number of microseconds between 1970 to 1601.
		timestamp = ((static_cast<uint64_t>(ft.dwHighDateTime) << 32) | ft.dwLowDateTime) / 10 - 11644473600000000;
#else
		struct timeval tv;
		gettimeofday(&tv, NULL);
		timestamp = tv.tv_sec * 1000 + tv.tv_usec/1000;
#endif
	}

	const uint64_t& get_timestamp() const {
		return timestamp;
	}

	void set_severity(int _severity) {
		severity = _severity;
	}

	int get_severity() const {
		return severity;
	}

private:
	int capacity;
	char* buffer;
	int write_index;
	int limit_index;
	int severity;
	uint64_t timestamp;
};

#endif
