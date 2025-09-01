cmake_minimum_required(VERSION 3.23)

project(AnthemEngine
  VERSION 0.0.1
  LANGUAGES CXX
)

add_library(project_options INTERFACE)
target_compile_features(project_options INTERFACE cxx_std_20)

# This cuts MSVC output by a factor of 10, due to warnings originating in
# upstream packages.
if(MSVC)
  # Disables a couple warnings about struct alignment (C4324, C4820), which
  # don't seem to indicate anything, though I may be wrong.
  #
  # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4324?view=msvc-170
  add_definitions("/wd4324")
  add_definitions("/wd4820")

  # Disables "relative include path contains '..'" warning, which shows up in
  # reflect-cpp.
  add_definitions("/wd4464")

  # I guess reflect-cpp just chucks GNU preprocessor macros into the void on
  # MSVC, and it makes the compiler unhappy.
  add_definitions("/wd4668")
endif()

# JUCE is having trouble finding GTK
if (LINUX)
  find_package(PkgConfig REQUIRED)
  find_package(CURL REQUIRED)
  pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
  pkg_check_modules(WEBKIT2GTK REQUIRED webkit2gtk-4.1)
endif()

add_subdirectory(include)

# Add JUCE

add_subdirectory(include/JUCE)

add_library(project_includes INTERFACE)
target_include_directories(project_includes INTERFACE
  # ${CMAKE_SOURCE_DIR}
  ${CMAKE_SOURCE_DIR}/src
  ${CMAKE_SOURCE_DIR}/src/modules
  ${CMAKE_SOURCE_DIR}/src/generated/lib/engine_api
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
  project_options
  project_includes

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



# Unit tests

add_executable(AnthemTest test/test.cpp ${ANTHEM_ENGINE_SOURCES})

target_link_libraries(AnthemTest
  PRIVATE
    project_options
    project_includes

    juce::juce_audio_basics
    juce::juce_audio_processors
    juce::juce_audio_devices

    reflectcpp
)

target_compile_definitions(AnthemTest PRIVATE JUCE_PLUGINHOST_VST3=1)

if (LINUX)
  target_include_directories(AnthemTest PRIVATE ${GTK3_INCLUDE_DIRS})
  target_link_directories(AnthemTest PRIVATE ${GTK3_LIBRARY_DIRS})
  target_link_libraries(AnthemTest PRIVATE ${GTK3_LIBRARIES})

  target_include_directories(AnthemTest PRIVATE ${WEBKIT2GTK_INCLUDE_DIRS})
  target_link_directories(AnthemTest PRIVATE ${WEBKIT2GTK_LIBRARY_DIRS})
  target_link_libraries(AnthemTest PRIVATE ${WEBKIT2GTK_LIBRARIES})

  target_link_libraries(AnthemTest PRIVATE CURL::libcurl)
  target_link_libraries(AnthemTest PRIVATE atomic)
endif()
