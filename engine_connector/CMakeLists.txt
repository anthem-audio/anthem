cmake_minimum_required(VERSION 3.15)

project(EngineConnector VERSION 1.0.0 LANGUAGES CXX)

# Set the C++ standard to C++11
set(CMAKE_CXX_STANDARD 11)

find_package(Boost 1.81.0 REQUIRED)

include_directories(${Boost_INCLUDE_DIR})
link_directories(${Boost_LIBRARY_DIRS})

# Include the cpp_shared directory
include_directories(${CMAKE_SOURCE_DIR}/../cpp_shared)

# Set the sources for the EngineConnector executable
set(ENGINE_CONNECTOR_SOURCES
    src/main.cpp
    ../cpp_shared/create_message_queue.h
    ../cpp_shared/create_message_queue.cpp
)

# Create the EngineConnector shared library (DLL)
add_library(EngineConnector SHARED ${ENGINE_CONNECTOR_SOURCES})

# Define the export symbol
target_compile_definitions(EngineConnector PRIVATE ENGINE_CONNECTOR_EXPORTS)

# Link with the Boost libraries
target_link_libraries(EngineConnector ${Boost_LIBRARIES})
