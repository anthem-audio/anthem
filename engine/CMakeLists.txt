cmake_minimum_required(VERSION 3.15)

project(AnthemEngine)

set(CMAKE_CXX_STANDARD 20)

# JUCE is having trouble finding GTK
if (LINUX)
  find_package(PkgConfig REQUIRED)
  find_package(CURL REQUIRED)
  pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
  pkg_check_modules(WEBKIT2GTK REQUIRED webkit2gtk-4.0)
endif()

# Set up Boost

find_package(Boost
  1.72.0
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
    src/anthem.h
    src/anthem.cpp
    src/plugin_window.h
    src/plugin_window.cpp
    src/command_handlers/project_command_handler.h
    src/command_handlers/project_command_handler.cpp
    generated/messages_generated.h
    generated/project_generated.h
    ../cpp_shared/open_message_queue.h
    ../cpp_shared/open_message_queue.cpp
)

target_sources(AnthemEngine PRIVATE ${ANTHEM_ENGINE_SOURCES})

# Create the AnthemEngine executable
# add_executable(AnthemEngine ${ANTHEM_ENGINE_SOURCES})

target_link_libraries(AnthemEngine ${Boost_LIBRARIES})

target_compile_definitions(AnthemEngine PRIVATE JUCE_PLUGINHOST_VST3=1)

if (LINUX)
  target_include_directories(AnthemEngine PRIVATE ${GTK3_INCLUDE_DIRS})
  target_link_directories(AnthemEngine PRIVATE ${GTK3_LIBRARY_DIRS})
  target_link_libraries(AnthemEngine PRIVATE ${GTK3_LIBRARIES})

  target_include_directories(AnthemEngine PRIVATE ${WEBKIT2GTK_INCLUDE_DIRS})
  target_link_directories(AnthemEngine PRIVATE ${WEBKIT2GTK_LIBRARY_DIRS})
  target_link_libraries(AnthemEngine PRIVATE ${WEBKIT2GTK_LIBRARIES})

  target_link_libraries(AnthemEngine PRIVATE CURL::libcurl)
  target_link_libraries(AnthemEngine PRIVATE atomic)
endif()

target_link_libraries(
  AnthemEngine

  PRIVATE
  tracktion::tracktion_engine
  juce::juce_gui_basics

  PUBLIC
  juce::juce_recommended_config_flags
  juce::juce_recommended_lto_flags
)

if (NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_link_libraries(
      AnthemEngine
      PUBLIC
      juce::juce_recommended_warning_flags
    )
endif()
