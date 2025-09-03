add_subdirectory(reflect-cpp)
target_compile_options(reflectcpp PRIVATE)

if (IS_WASM)
  set(JUCE_CORE_WASM_SOURCES
    juce_core_wasm.cpp
    juce_core_wasm.h
  )

  add_library(juce_core_wasm STATIC ${JUCE_CORE_WASM_SOURCES})

  target_include_directories(juce_core_wasm
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  )
endif()
