cmake_minimum_required(VERSION 3.23)

project(AnthemNativeIpc LANGUAGES CXX)

add_library(anthem_native_ipc STATIC
  src/shared_memory_region_c_api.cpp
)

if(WIN32)
  target_sources(anthem_native_ipc PRIVATE
    src/shared_memory_region_windows.cpp
  )
elseif(UNIX)
  target_sources(anthem_native_ipc PRIVATE
    src/shared_memory_region_posix.cpp
  )
else()
  message(FATAL_ERROR "anthem_native_ipc does not support this platform")
endif()

target_compile_features(anthem_native_ipc PUBLIC cxx_std_20)
target_compile_definitions(anthem_native_ipc PUBLIC ANTHEM_NATIVE_IPC_STATIC)
target_include_directories(anthem_native_ipc PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  target_link_libraries(anthem_native_ipc PUBLIC rt)
endif()

add_library(anthem::native_ipc ALIAS anthem_native_ipc)
