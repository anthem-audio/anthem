# cspell:ignore strequal pluginhost

cmake_minimum_required(VERSION 3.23)

project(AnthemEngine
  VERSION 0.0.1
  LANGUAGES C CXX
)

# clangd and clang-tidy rely on this on generators that support compile
# database export.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(IS_WASM FALSE)
if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
  set(IS_WASM TRUE)
endif()

if (IS_WASM)
  set(EXPORTED_FUNCTIONS
    _main
    _isCommsReady

    _getWriteBufferHeadPtr
    _getWriteBufferTailPtr
    _getWriteBufferCapacity
    _getWriteBufferMask
    _getWriteBufferDataPtr
    _getWriteBufferTicketPtr

    _getReadBufferHeadPtr
    _getReadBufferTailPtr
    _getReadBufferCapacity
    _getReadBufferMask
    _getReadBufferDataPtr
    _getReadBufferTicketPtr
  )

  string(JOIN "," EXPORTED_FUNCTIONS_STRING ${EXPORTED_FUNCTIONS})

  # CMake's Threads package maps to '-pthread' under Emscripten.
  find_package(Threads REQUIRED)

  add_compile_options(
    -pthread

    # "SHELL:-fsanitize=address"
  )
  
  add_link_options(
    -pthread
    # The value 3 here maps to 3 threads in the engine:
    # - Message thread
    # - Audio thread
    # - Comms thread
    "SHELL:-sPTHREAD_POOL_SIZE=3"
    "SHELL:-sPROXY_TO_PTHREAD=1"

    "SHELL:-INITIAL_HEAP=268435456" # 256MB
    "SHELL:-sALLOW_MEMORY_GROWTH=1"

    "SHELL:-sMODULARIZE=1"
    "SHELL:-sEXIT_RUNTIME=1"

    "SHELL:-sEXPORT_NAME=AnthemEngine"
    "SHELL:-sEXPORTED_FUNCTIONS='[${EXPORTED_FUNCTIONS_STRING}]'"
    "SHELL:-sEXPORTED_RUNTIME_METHODS='[\"HEAPU8\", \"HEAPU32\", \"HEAP32\", \"HEAPF32\"]'"
  )

  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_link_options(
      "SHELL:-gsource-map"
      "SHELL:-g"
    )
  endif()
endif()

add_library(project_options INTERFACE)
target_compile_features(project_options INTERFACE cxx_std_20)

# This cuts MSVC output by a factor of 10, due to warnings originating in
# upstream packages.
if(MSVC)
  # Treat angle-bracket includes as external, and silence warnings from them.
  # This keeps third-party header noise (e.g. reflect-cpp/JUCE internals) out
  # of our build output.
  add_compile_options("/external:anglebrackets")
  add_compile_options("/external:W0")
  add_compile_options("/Zc:__cplusplus")
endif()

# JUCE can't find GTK without this
if (LINUX AND NOT IS_WASM)
  find_package(PkgConfig REQUIRED)
  find_package(CURL REQUIRED)
  pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
  pkg_check_modules(WEBKIT2GTK REQUIRED webkit2gtk-4.1)
endif()

# Disables Juceaide. This is required when compiling under Emscripten.
if (IS_WASM)
  set(JUCE_MODULES_ONLY ON)
endif()

add_subdirectory(include)          # Third-party libraries excluding JUCE
add_subdirectory(include/JUCE)     # JUCE (this is our fork with WASM support)

add_library(project_includes INTERFACE)
target_include_directories(project_includes INTERFACE
  ${PROJECT_SOURCE_DIR}/src
  ${PROJECT_SOURCE_DIR}/src/generated/lib/engine_api
)

# Source files
file(
  GLOB_RECURSE
  ANTHEM_ALL_SOURCES
  CONFIGURE_DEPENDS
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

    reflectcpp
    brickworks::brickworks
)

if (IS_WASM)
  target_link_libraries(AnthemEngineLib
    PUBLIC
      Threads::Threads
      juce::juce_core
      juce::juce_events
      juce::juce_audio_basics
      # juce::juce_audio_processors
      juce::juce_audio_devices
  )
else()
  target_link_libraries(AnthemEngineLib
    PUBLIC
      juce::juce_core
      juce::juce_events
      juce::juce_audio_basics
      juce::juce_audio_processors
      juce::juce_audio_devices

      juce::juce_recommended_config_flags
      juce::juce_recommended_lto_flags
  )

  target_compile_definitions(AnthemEngineLib PUBLIC JUCE_PLUGINHOST_VST3=1)

  if (NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_link_libraries(AnthemEngineLib PUBLIC juce::juce_recommended_warning_flags)
  endif()

  if (LINUX)
    target_include_directories(AnthemEngineLib PUBLIC ${GTK3_INCLUDE_DIRS} ${WEBKIT2GTK_INCLUDE_DIRS})
    target_link_directories(AnthemEngineLib PUBLIC ${GTK3_LIBRARY_DIRS} ${WEBKIT2GTK_LIBRARY_DIRS})
    target_link_libraries(AnthemEngineLib PUBLIC ${GTK3_LIBRARIES} ${WEBKIT2GTK_LIBRARIES})
    target_link_libraries(AnthemEngineLib PUBLIC CURL::libcurl atomic)
  endif()
endif()


# -------------------------------------------------------------------
# Main console application
# -------------------------------------------------------------------

if (IS_WASM)
  add_executable(AnthemEngine
    ${APP_MAIN}
  )
else()
  juce_add_console_app(AnthemEngine ANTHEM_ENGINE "Anthem Engine" VERSION "${PROJECT_VERSION}")

  target_sources(AnthemEngine PRIVATE ${APP_MAIN})
endif()

# Temporarily link WASM build to custom JUCE lib for testing
if (IS_WASM)
  target_link_libraries(AnthemEngine
    PRIVATE
      Threads::Threads
      AnthemEngineLib
  )
endif()

# Tests rely on JUCE, so skipping for WASM for now
if (NOT IS_WASM)
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
  if (LINUX)
    target_include_directories(AnthemTest PRIVATE ${GTK3_INCLUDE_DIRS} ${WEBKIT2GTK_INCLUDE_DIRS})
    target_link_directories(AnthemTest PRIVATE ${GTK3_LIBRARY_DIRS} ${WEBKIT2GTK_LIBRARY_DIRS})
    target_link_libraries(AnthemTest PRIVATE CURL::libcurl atomic)
  endif()
endif()
