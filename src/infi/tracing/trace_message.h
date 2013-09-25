#ifndef __trace_message_h__
#define __trace_message_h__

#include <stdarg.h>
#include <algorithm>
#include <cstring>
#include <boost/assert.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>

#define SEVERITY_NOTSET (-1)

template <typename T>
T clip(const T& n, const T& lower, const T& upper) {
  return std::max(lower, std::min(n, upper));
}

class TraceMessage {
public:
	typedef boost::posix_time::ptime ptime;
	typedef boost::posix_time::microsec_clock microsec_clock;

	TraceMessage(int _capacity=0): 
		capacity(0), buffer(0), write_index(0), limit_index(0), severity(SEVERITY_NOTSET), timestamp() {
		if (_capacity != 0) {
			realloc(_capacity);
		}
	}

	~TraceMessage() {
		delete[] buffer;
	}

	void operator=(const TraceMessage& other) {
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
		timestamp = ptime();
	}

	void realloc(int new_capacity) {
		delete[] buffer;
		capacity = new_capacity;
		buffer = new char[capacity + 1];
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
		timestamp = microsec_clock::universal_time();
	}

	const ptime& get_timestamp() const {
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
	ptime timestamp;
};

#endif
