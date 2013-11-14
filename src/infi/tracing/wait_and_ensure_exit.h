#ifndef __wait_and_ensure_exit_h__
#define __wait_and_ensure_exit_h__

#include <boost/thread.hpp>
#include <boost/smart_ptr.hpp>

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
	boost::scoped_ptr<boost::thread> thread;
};

#endif // __wait_and_ensure_exit_h__