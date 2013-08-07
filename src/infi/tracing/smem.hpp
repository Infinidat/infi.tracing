//////////////////////////////////////////////////////////////////////////////
//Dustin Juliano, 2/1/2013, New BSD License
//Copyright © 2013, Juliano Research Corporation
//All rights reserved.
//http://julianoresearch.com
//
//Redistribution and use in source and binary forms, with or without
//modification, are permitted provided that the following conditions are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//    * Neither the name of the Juliano Research Corporation nor the
//      names of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//DISCLAIMED. IN NO EVENT SHALL JULIANO RESEARCH CORPORATION BE LIABLE FOR ANY
//DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//////////////////////////////////////////////////////////////////////////////
#pragma once
#define __STDC_CONSTANT_MACROS
#include <stdint.h>
#ifdef WIN32
    #include <cstdint>
#else
    #include <inttypes.h>
#endif
#include <cstdlib>
#include <stdexcept>
//////////////////////////////////////////////////////////////////////////////
//WIN 32/64
#if defined(_WIN32) || defined(_WIN64)
	#if defined(_WIN64)
		#define ENVIRONMENT64
	#else
		#define ENVIRONMENT32
	#endif
#endif
//GCC 32/64
#if defined(__GNUC__)
	#if defined(__x86_64__) || defined(__ppc64__)
		#define ENVIRONMENT64
	#else
		#define ENVIRONMENT32
	#endif
#endif
//////////////////////////////////////////////////////////////////////////////
//class smem
//
//static memory allocator template class
//////////////////////////////////////////////////////////////////////////////
template <typename T>
class smem {
//////////////////////////////////////////////////////////////////////////////
//member data
//////////////////////////////////////////////////////////////////////////////
protected:
    struct term {
        T* slot;
        term *next;
    };
    T *slots;
    term *freelist;
    term *freebase;
    const uint64_t m_capacity;
//////////////////////////////////////////////////////////////////////////////
//member functions
//////////////////////////////////////////////////////////////////////////////
public:
    //////////////////////////////////////////////////////////////////////////////
    //constructor
    //////////////////////////////////////////////////////////////////////////////
    inline explicit smem(uint32_t count) : m_capacity(count) {
        //size optimization check:
        #if defined(ENVIRONMENT64)
            if (sizeof(term) != 16) throw std::runtime_error("expected smem term size = 16 bytes on 64-bit platform.");
        #elif defined(ENVIRONMENT32)
            if (sizeof(term) != 8) throw std::runtime_error("expected smem term size = 8 bytes on 32-bit platform.");
        #else
            #error Platform not yet supported.
        #endif
        //proceed with initialization
        T *p = slots = new T[count];
        term *f = freelist = freebase = new term[count];
        if ((!p) || (!f)) throw std::bad_alloc();
        const uint64_t e = count - 1;
        for (uint64_t i = 0;; i++) {
            f->slot = p;
            if (i == e) {
                f->next = NULL;
                break;
            }//if
            else {
                f->next = f + 1;
                ++p;
                ++f;
            }//else
        }//for
    }//constructor
    //////////////////////////////////////////////////////////////////////////////
    //destructor
    //////////////////////////////////////////////////////////////////////////////
    ~smem() {
        delete[] slots;
        delete[] freebase;
        slots = NULL;
        freebase = NULL;
        freelist = NULL;
    }//destructor
    //////////////////////////////////////////////////////////////////////////////
    //mapterm
    //
    //maps internal node address to memory address for T
    //////////////////////////////////////////////////////////////////////////////
    inline T* mapterm(term *termptr) const {
        //map term -> slot
        #if defined(ENVIRONMENT64)
        return (slots +
            ((reinterpret_cast<uint8_t*>(termptr) -
                reinterpret_cast<uint8_t*>(freebase)) >> 4));
        #elif defined(ENVIRONMENT32)
        return (slots +
            ((reinterpret_cast<uint8_t*>(termptr) -
                reinterpret_cast<uint8_t*>(freebase)) >> 3));
        #else
        return (slots +
            ((reinterpret_cast<uint8_t*>(termptr) -
                reinterpret_cast<uint8_t*>(freebase))
                / sizeof(term)));
        #endif
    }//mapterm
    //////////////////////////////////////////////////////////////////////////////
    //mapslot
    //
    //maps memory address for T to internal node address
    //////////////////////////////////////////////////////////////////////////////
    inline term* mapslot(T *slotptr) const {
        //map slot -> term
        return (freebase +
            ((reinterpret_cast<uint8_t*>(slotptr) -
                reinterpret_cast<uint8_t*>(slots)) / sizeof(T)));
    }//mapslot
    //////////////////////////////////////////////////////////////////////////////
    //alloc
    //
    //allocates from the freelist; caller takes responsibility for bounds
    //////////////////////////////////////////////////////////////////////////////
    inline T* alloc() {
        term *t = freelist;
        freelist = freelist->next;
        return mapterm(t);
    }//alloc
    //////////////////////////////////////////////////////////////////////////////
    //free
    //
    //returns the slot to the freestore; does not call delete or free
    //does not call the destructor for the object pointed to in memory
    //////////////////////////////////////////////////////////////////////////////
    inline void free(T *ptr) {
        term *t = mapslot(ptr);
        t->next = freelist;
        freelist = t;
    }//free
    //////////////////////////////////////////////////////////////////////////////
    //purge
    //
    //drops all tracked blocks and fills the freelist
    //warning: copy constructs each slot to re-initialize it
    //////////////////////////////////////////////////////////////////////////////
    inline void purge() {
        const uint64_t e = m_capacity - 1;
        term *f = freelist = freebase;
        T *p = slots;
        for (uint64_t i = 0;; i++) {
            *p = T();
            f->slot = p;
            if (i == e) {
                f->next = NULL;
                break;
            }//if
            else {
                f->next = f + 1;
                ++p;
                ++f;
            }//else
        }//for
    }//purge
};//class smem
//////////////////////////////////////////////////////////////////////////////