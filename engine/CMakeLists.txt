cmake_minimum_required(VERSION 3.15)

project(AnthemEngine)

# Set the C++ standard to C++11
set(CMAKE_CXX_STANDARD 11)

find_package(Boost
  1.81.0
  REQUIRED
)

include_directories( ${Boost_INCLUDE_DIR} )
link_directories( ${Boost_LIBRARY_DIRS} )

include_directories(${CMAKE_SOURCE_DIR}/include)

include_directories(${CMAKE_SOURCE_DIR}/generated)

# Include the cpp_shared directory
include_directories(${CMAKE_SOURCE_DIR}/../cpp_shared)

# Set the sources for the AnthemEngine executable
set(ANTHEM_ENGINE_SOURCES
    src/main.cpp
    generated/messages_generated.h
    ../cpp_shared/open_message_queue.h
    ../cpp_shared/open_message_queue.cpp
)

# Create the AnthemEngine executable
add_executable(AnthemEngine ${ANTHEM_ENGINE_SOURCES})

target_link_libraries(AnthemEngine ${Boost_LIBRARIES})
