cmake_minimum_required(VERSION 3.15)

project(AnthemEngine)

set(CMAKE_CXX_STANDARD 20)

# Set up Boost

find_package(Boost
  1.81.0
  REQUIRED
)

include_directories( ${Boost_INCLUDE_DIR} )
link_directories( ${Boost_LIBRARY_DIRS} )

include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_SOURCE_DIR}/generated)

# Add JUCE and Tracktion Engine

add_subdirectory(include/JUCE)
add_subdirectory(include/tracktion_engine)

# Include the cpp_shared directory
include_directories(${CMAKE_SOURCE_DIR}/../cpp_shared)

# Make this a JUCE console application
juce_add_console_app(AnthemEngine ANTHEM_ENGINE "Anthem Engine" VERSION "0.0.1")

# Set the sources for the AnthemEngine executable
set(ANTHEM_ENGINE_SOURCES
    src/main.cpp
    generated/messages_generated.h
    ../cpp_shared/open_message_queue.h
    ../cpp_shared/open_message_queue.cpp
)

target_sources(AnthemEngine PRIVATE ${ANTHEM_ENGINE_SOURCES})

# Create the AnthemEngine executable
# add_executable(AnthemEngine ${ANTHEM_ENGINE_SOURCES})

target_link_libraries(AnthemEngine ${Boost_LIBRARIES})

target_link_libraries(
  AnthemEngine

  PRIVATE
  juce::juce_audio_utils
  tracktion::tracktion_engine

  PUBLIC
  juce::juce_recommended_config_flags
  juce::juce_recommended_lto_flags
  juce::juce_recommended_warning_flags
)
