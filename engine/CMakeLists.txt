cmake_minimum_required(VERSION 3.23)

project(AnthemEngine)

set(CMAKE_CXX_STANDARD 20)

# JUCE is having trouble finding GTK
if (LINUX)
  find_package(PkgConfig REQUIRED)
  find_package(CURL REQUIRED)
  pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
  pkg_check_modules(WEBKIT2GTK REQUIRED webkit2gtk-4.0)
endif()

add_subdirectory(include)

include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_SOURCE_DIR}/include)

# Add JUCE

add_subdirectory(include/JUCE)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

include_directories(
  ${CMAKE_SOURCE_DIR}

  # Allows #include "messages/messages.h" for generated messages
  ${CMAKE_SOURCE_DIR}/generated/lib/engine_api

  ${CMAKE_SOURCE_DIR}/src
  ${CMAKE_SOURCE_DIR}/src/modules
)

# Make this a JUCE console application
juce_add_console_app(AnthemEngine ANTHEM_ENGINE "Anthem Engine" VERSION "0.0.1")

# Add the source files
file(
  GLOB_RECURSE
  ANTHEM_ENGINE_SOURCES
  ${PROJECT_SOURCE_DIR}/src/*.h
  ${PROJECT_SOURCE_DIR}/src/*.cpp
  ${PROJECT_SOURCE_DIR}/src/**/*.h
  ${PROJECT_SOURCE_DIR}/src/**/*.cpp
)

target_sources(AnthemEngine PRIVATE ${ANTHEM_ENGINE_SOURCES})


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
  juce::juce_audio_processors
  juce::juce_audio_basics
  juce::juce_audio_devices

  reflectcpp

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
