#include "wait_and_ensure_exit.h"
#include <unistd.h>

WaitAndEnsureExit::WaitAndEnsureExit() : seconds(0), exit_code(10), thread() {
}


WaitAndEnsureExit::~WaitAndEnsureExit() {}


void WaitAndEnsureExit::go(int seconds, int exit_code) {
	this->seconds = seconds;
	this->exit_code = exit_code;
	thread.reset(new boost::thread(&WaitAndEnsureExit::thread_func, this));
}


void WaitAndEnsureExit::thread_func() {
	::sleep(seconds);
	::_exit(exit_code);
}