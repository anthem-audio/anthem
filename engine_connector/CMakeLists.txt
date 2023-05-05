cmake_minimum_required(VERSION 3.15)

project(EngineConnector VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)

find_package(Boost 1.72.0 REQUIRED)

include_directories(${Boost_INCLUDE_DIR})
link_directories(${Boost_LIBRARY_DIRS})

# Include the cpp_shared directory
include_directories(${CMAKE_SOURCE_DIR}/../cpp_shared)

# Set the sources for the EngineConnector executable
set(ENGINE_CONNECTOR_SOURCES
    src/main.cpp
    ../cpp_shared/open_message_queue.h
    ../cpp_shared/open_message_queue.cpp
)

# Create the EngineConnector dynamic library
add_library(EngineConnector SHARED ${ENGINE_CONNECTOR_SOURCES})

# Define the export symbol
target_compile_definitions(EngineConnector PRIVATE ENGINE_CONNECTOR_EXPORTS)

# Link with the Boost libraries
target_link_libraries(EngineConnector ${Boost_LIBRARIES})

# Add platform-specific linker flags
if (MSVC)
    target_link_options(EngineConnector PRIVATE "/INCREMENTAL:NO")
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set_target_properties(EngineConnector PROPERTIES LINK_FLAGS "-Wl,--no-undefined")
endif ()
