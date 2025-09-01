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

add_subdirectory(include)          # Third-party libraries excluding JUCE
add_subdirectory(include/JUCE)     # JUCE

add_library(project_includes INTERFACE)
target_include_directories(project_includes INTERFACE
  ${CMAKE_SOURCE_DIR}/src
  ${CMAKE_SOURCE_DIR}/src/generated/lib/engine_api
)

# Source files
file(
  GLOB_RECURSE
  ANTHEM_ALL_SOURCES
  ${PROJECT_SOURCE_DIR}/src/*.h
  ${PROJECT_SOURCE_DIR}/src/*.cpp
  ${PROJECT_SOURCE_DIR}/src/**/*.h
  ${PROJECT_SOURCE_DIR}/src/**/*.cpp
)

# Identify the application entry point so it is NOT compiled into the library.
set(APP_MAIN ${PROJECT_SOURCE_DIR}/src/main.cpp)

# Build the engine/library sources by excluding the app main file.
set(ANTHEM_ENGINE_SOURCES ${ANTHEM_ALL_SOURCES})
list(REMOVE_ITEM ANTHEM_ENGINE_SOURCES ${APP_MAIN})

# Build a reusable library target
add_library(AnthemEngineLib STATIC
  ${ANTHEM_ENGINE_SOURCES}
)

target_link_libraries(AnthemEngineLib
  PUBLIC
    project_options
    project_includes

    juce::juce_audio_processors
    juce::juce_audio_basics
    juce::juce_audio_devices

    reflectcpp

    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
)

target_compile_definitions(AnthemEngineLib PUBLIC JUCE_PLUGINHOST_VST3=1)

if (NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_link_libraries(AnthemEngineLib PUBLIC juce::juce_recommended_warning_flags)
endif()

if (UNIX AND NOT APPLE AND NOT EMSCRIPTEN)
  target_include_directories(AnthemEngineLib PUBLIC ${GTK3_INCLUDE_DIRS} ${WEBKIT2GTK_INCLUDE_DIRS})
  target_link_directories(AnthemEngineLib PUBLIC ${GTK3_LIBRARY_DIRS} ${WEBKIT2GTK_LIBRARY_DIRS})
  target_link_libraries(AnthemEngineLib PUBLIC ${GTK3_LIBRARIES} ${WEBKIT2GTK_LIBRARIES})
  target_link_libraries(AnthemEngineLib PUBLIC CURL::libcurl atomic)
endif()

# -------------------------------------------------------------------
# Main console application
# -------------------------------------------------------------------
juce_add_console_app(AnthemEngine ANTHEM_ENGINE "Anthem Engine" VERSION "${PROJECT_VERSION}")

# Only the app’s entry point is compiled here; all other sources come from the library.
# If your app has additional app-only .cpp files, add them here as well.
target_sources(AnthemEngine PRIVATE ${APP_MAIN})

target_link_libraries(
  AnthemEngine
  PRIVATE
    AnthemEngineLib
)

# -------------------------------------------------------------------
# Unit tests
# -------------------------------------------------------------------
add_executable(AnthemTest
  test/test.cpp
)

target_link_libraries(AnthemTest
  PRIVATE
    AnthemEngineLib
)

# Linux desktop bits for the test binary (they will already be inherited via the
# lib, but these are here in case we want to add test-only code later that needs
# the include dirs directly)
if (UNIX AND NOT APPLE AND NOT EMSCRIPTEN)
  target_include_directories(AnthemTest PRIVATE ${GTK3_INCLUDE_DIRS} ${WEBKIT2GTK_INCLUDE_DIRS})
  target_link_directories(AnthemTest PRIVATE ${GTK3_LIBRARY_DIRS} ${WEBKIT2GTK_LIBRARY_DIRS})
  target_link_libraries(AnthemTest PRIVATE CURL::libcurl atomic)
endif()
