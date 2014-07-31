#ifndef __test_utils_h__
#define __test_utils_h__

#define TEST(x) \
    if (!x()) { \
        fprintf(stderr, "test " #x " failed\n"); \
        test_failed = true; \
    } else { \
        printf("test " #x " passed.\n"); \
    }


#define ASSERT(a) \
    if (!(a)) { \
        fprintf(stderr, "assertion failed: " #a ", failing test.\n"); \
        return false; \
    }

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) { \
        fprintf(stderr, "assertion failed: " #a " != " #b ", failing test.\n"); \
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
