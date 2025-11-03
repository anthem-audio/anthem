# reflect-cpp

add_subdirectory(reflect-cpp)
target_compile_options(reflectcpp PRIVATE)

# Brickworks

add_library(brickworks_headers INTERFACE)

target_include_directories(brickworks_headers
  SYSTEM
  INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/brickworks/include 
)

add_library(brickworks::brickworks ALIAS brickworks_headers)
