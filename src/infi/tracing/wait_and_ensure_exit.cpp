#include "wait_and_ensure_exit.h"
#include <unistd.h>


static void* _waitandensureexit_thread_func_trampoline(void* ptr) {
    static_cast<WaitAndEnsureExit*>(ptr)->thread_func();
    return NULL;
}


WaitAndEnsureExit::WaitAndEnsureExit() : seconds(0), exit_code(10), thread() {
}


WaitAndEnsureExit::~WaitAndEnsureExit() {}


void WaitAndEnsureExit::go(int seconds, int exit_code) {
	this->seconds = seconds;
	this->exit_code = exit_code;
    // TODO assume success
    mint_thread_create(&this->thread, _waitandensureexit_thread_func_trampoline, this);
}


void WaitAndEnsureExit::thread_func() {
	::sleep(seconds);
	::_exit(exit_code);
}