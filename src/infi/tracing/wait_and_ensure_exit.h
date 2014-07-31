#ifndef __wait_and_ensure_exit_h__
#define __wait_and_ensure_exit_h__

#include <mintsystem/thread.h>

static void* _waitandensureexit_thread_func_trampoline(void* ptr);

class WaitAndEnsureExit {
public:
	WaitAndEnsureExit();
	~WaitAndEnsureExit();

	void go(int seconds, int exit_code);

protected:
	void thread_func();

private:
	int seconds;
	int exit_code;
    mint_thread_t thread;

    friend void* _waitandensureexit_thread_func_trampoline(void*);
};

#endif // __wait_and_ensure_exit_h__