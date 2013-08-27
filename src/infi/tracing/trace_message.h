#ifndef __trace_message_h__
#define __trace_message_h__

#include <stdarg.h>
#include <algorithm>

#define TRACE_MESSAGE_MAX_SIZE (1024 - 1)

template <typename T>
T clip(const T& n, const T& lower, const T& upper) {
  return std::max(lower, std::min(n, upper));
}

class TraceMessage {
public:
	TraceMessage() {
		recycle();
	}

	void recycle() {
		write_index = 0;
		limit_index = TRACE_MESSAGE_MAX_SIZE;
		buffer[0] = buffer[TRACE_MESSAGE_MAX_SIZE] = '\0';
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
		limit_index = TRACE_MESSAGE_MAX_SIZE;
	}

	void unlimit(int i) {
		limit_index = clip(i, 0, TRACE_MESSAGE_MAX_SIZE);
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

private:
	char buffer[TRACE_MESSAGE_MAX_SIZE + 1];
	int write_index;
	int limit_index;
};

#endif