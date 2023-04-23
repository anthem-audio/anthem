#include <boost/interprocess/ipc/message_queue.hpp>
#include <thread>
#include <chrono>

using namespace boost::interprocess;

std::unique_ptr<message_queue> openMessageQueue(const char *name);
