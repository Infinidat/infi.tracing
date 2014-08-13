#include "lru.hpp"
#include "test_utils.h"
#include <stdlib.h>

bool test_alloc_dealloc() {
    LRU(0);
    LRU(1);
    LRU(1024);
    return true;
};

bool test_lru__single_elem() {
    LRU lru(1);
    lru.insert(42, 24);
    ASSERT_EQ(lru.find(42), 24);
    ASSERT_EQ(lru.find(4), -1);
    lru.insert(56, 65);
    ASSERT_EQ(lru.find(42), -1);
    ASSERT_EQ(lru.find(56), 65);
    return true;
}

bool test_lru__eviction_policy() {
    {
        LRU lru(2);
        lru.insert(1, 10);
        lru.insert(2, 20);
        lru.find(1);
        lru.find(2);
        lru.find(1);
        lru.insert(3, 30);
        ASSERT_EQ(lru.find(2), -1);
        ASSERT_EQ(lru.find(3), 30);
    }

    {
        LRU lru(2);
        lru.insert(1, 10);
        lru.insert(2, 20);
        lru.find(1);
        lru.find(2);
        lru.find(2);
        lru.insert(3, 30);
        ASSERT_EQ(lru.find(1), -1);
        ASSERT_EQ(lru.find(3), 30);
    }

    return true;
}

bool test_lru__eviction_policy_big() {
    {
        LRU lru(256);
        for (int i = 0; i < 256; ++i) {
            lru.insert(i, 1);
        }
        for (int i = 0; i < 255; ++i) {
            lru.find(i);
        }
        lru.insert(256, 1);
        ASSERT_EQ(lru.find(255), -1);
    }
    {
        LRU lru(256);
        for (int i = 0; i < 256; ++i) {
            lru.insert(i, 1);
        }
        for (int i = 1; i < 256; ++i) {
            lru.find(i);
        }
        lru.insert(256, 1);
        ASSERT_EQ(lru.find(0), -1);
    }
}

bool test_lru__random() {
    srandom(0);
    LRU lru(256);
    for (int i = 0; i < 256; ++i) {
        lru.insert(i, 1);
    }

    int unused_key = 256;
    for (int i = 0; i < 1024; ++i) {
        if ((random() % 2) == 1) {
            lru.insert(unused_key++, 1);
        } else {
            lru.find(random() % unused_key);
        }
    }

    return true;
}

MAIN_TEST_CASE_BEGIN
    TEST(test_alloc_dealloc);
    TEST(test_lru__single_elem);
    TEST(test_lru__eviction_policy);
    TEST(test_lru__eviction_policy_big);
    TEST(test_lru__random);
MAIN_TEST_CASE_END
