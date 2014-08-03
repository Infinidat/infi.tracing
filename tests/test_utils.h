#ifndef __test_utils_h__
#define __test_utils_h__

#include <stdio.h>

#define TEST(x) \
    if (!x()) { \
        fprintf(stderr, "test " #x " failed\n"); \
        test_failed = true; \
    } else { \
        printf("test " #x " passed.\n"); \
    }

#define ASSERT(a) \
    if (!(a)) { \
        fprintf(stderr, "assertion failed at %s:%d: " #a ", failing test.\n", __FILE__, __LINE__); \
        return false; \
    }

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) { \
        fprintf(stderr, "assertion failed at %s:%d: " #a " != " #b ", failing test.\n", __FILE__, __LINE__); \
        return false; \
    }

#define FAIL(message) \
    { \
        fprintf(stderr, "test failed at %s:%d: " #message, __FILE__, __LINE__); \
        return false; \
    }

#define MAIN_TEST_CASE_BEGIN \
    int main(int, char**) { \
        bool test_failed = false;

#define MAIN_TEST_CASE_END \
        if (test_failed) { \
            fprintf(stderr, "ERROR: one or more tests failed.\n"); \
        } else { \
            printf("success: all tests passed.\n"); \
        } \
        return test_failed ? 1 : 0; \
    }

#endif // __test_utils_h__
