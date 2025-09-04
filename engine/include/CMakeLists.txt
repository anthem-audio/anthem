add_subdirectory(reflect-cpp)
target_compile_options(reflectcpp PRIVATE)

# For WASM, we construct a subset of JUCE that will compile under Emscripten.
# This requires creating custom modules (e.g. juce_core.h -> juce_core_wasm.h)
# that strip out non-WASM compatible code (e.g. file I/O).
if (IS_WASM)
  add_library(juce_wasm_config INTERFACE)
  target_compile_definitions(juce_wasm_config INTERFACE
    JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1
  )

  # ---------
  # juce_core
  # ---------

  set(JUCE_CORE_WASM_SOURCES
    juce_core_wasm.h
    juce_core_wasm.cpp
  )

  add_library(juce_core_wasm STATIC ${JUCE_CORE_WASM_SOURCES})

  target_include_directories(juce_core_wasm
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/JUCE/modules>
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/JUCE/modules/juce_core>
  )

  target_link_libraries(juce_core_wasm
    PUBLIC
      juce_wasm_config
      wasm_pthreads
      Threads::Threads
  )

  # -----------------
  # juce_audio_basics
  # -----------------

  set(JUCE_AUDIO_BASICS_WASM_SOURCES
    juce_audio_basics_wasm.h
    juce_audio_basics_wasm.cpp
  )

  add_library(juce_audio_basics_wasm STATIC ${JUCE_AUDIO_BASICS_WASM_SOURCES})

  target_include_directories(juce_audio_basics_wasm
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/JUCE/modules>
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/JUCE/modules/juce_audio_basics>
  )

  target_link_libraries(juce_audio_basics_wasm
    PUBLIC
      juce_wasm_config
      juce_core_wasm
      wasm_pthreads
      Threads::Threads
  )
endif()
