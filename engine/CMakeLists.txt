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

# Include the cpp_shared directory
include_directories(${CMAKE_SOURCE_DIR}/../cpp_shared)

# Include module folders so we don't have to use relative paths
include_directories(
  ${CMAKE_SOURCE_DIR}/src/modules/core
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph/compiler
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph/compiler/actions
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph/debug
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph/processor
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph/runtime
  ${CMAKE_SOURCE_DIR}/src/modules/processing_graph/topology
  ${CMAKE_SOURCE_DIR}/src/modules/processors
  ${CMAKE_SOURCE_DIR}/src/modules/util
)

# Make this a JUCE console application
juce_add_console_app(AnthemEngine ANTHEM_ENGINE "Anthem Engine" VERSION "0.0.1")

# Set the sources for the AnthemEngine executable
set(ANTHEM_ENGINE_SOURCES
  generated/messages_generated.h
  generated/project_generated.h

  ../cpp_shared/open_message_queue.cpp
  ../cpp_shared/open_message_queue.h

  src/command_handlers/processing_graph_command_handler.cpp
  src/command_handlers/processing_graph_command_handler.h
  src/command_handlers/processor_command_handler.cpp
  src/command_handlers/processor_command_handler.h
  src/command_handlers/project_command_handler.cpp
  src/command_handlers/project_command_handler.h

  #############################
  #         Modules           #
  #############################

  ### Core ###

  src/modules/core/anthem_audio_callback.cpp
  src/modules/core/anthem_audio_callback.h
  src/modules/core/anthem.cpp
  src/modules/core/anthem.h
  src/modules/core/constants.h

  ### Processing Graph ###
  
  src/modules/processing_graph/compiler/actions/anthem_graph_compiler_action.h
  src/modules/processing_graph/compiler/actions/copy_audio_buffer_action.cpp
  src/modules/processing_graph/compiler/actions/copy_audio_buffer_action.h
  src/modules/processing_graph/compiler/actions/copy_control_buffer_action.cpp
  src/modules/processing_graph/compiler/actions/copy_control_buffer_action.h
  src/modules/processing_graph/compiler/actions/process_node_action.cpp
  src/modules/processing_graph/compiler/actions/process_node_action.h
  src/modules/processing_graph/compiler/actions/write_parameters_to_control_inputs_action.cpp
  src/modules/processing_graph/compiler/actions/write_parameters_to_control_inputs_action.h
  src/modules/processing_graph/compiler/actions/zero_input_buffers_action.cpp
  src/modules/processing_graph/compiler/actions/zero_input_buffers_action.h
  # src/modules/processing_graph/compiler/anthem_graph_compilation_result.cpp
  src/modules/processing_graph/compiler/anthem_graph_compilation_result.h
  src/modules/processing_graph/compiler/anthem_graph_compiler_edge.h
  src/modules/processing_graph/compiler/anthem_graph_compiler_node.h
  src/modules/processing_graph/compiler/anthem_graph_compiler.cpp
  src/modules/processing_graph/compiler/anthem_graph_compiler.h
  src/modules/processing_graph/compiler/anthem_process_context.cpp
  src/modules/processing_graph/compiler/anthem_process_context.h

  src/modules/processing_graph/debug/generate_graphvis_from_graph.cpp
  src/modules/processing_graph/debug/generate_graphvis_from_graph.h

  src/modules/processing_graph/processor/anthem_processor_config.cpp
  src/modules/processing_graph/processor/anthem_processor_config.h
  # src/modules/processing_graph/processor/anthem_processor_parameter_config.cpp
  src/modules/processing_graph/processor/anthem_processor_parameter_config.h
  # src/modules/processing_graph/processor/anthem_processor_port_config.cpp
  src/modules/processing_graph/processor/anthem_processor_port_config.h
  # src/modules/processing_graph/processor/anthem_processor.cpp
  src/modules/processing_graph/processor/anthem_processor.h

  src/modules/processing_graph/runtime/anthem_graph_processor.cpp
  src/modules/processing_graph/runtime/anthem_graph_processor.h

  src/modules/processing_graph/topology/anthem_graph_data_type.h
  # src/modules/processing_graph/topology/anthem_graph_node_port.cpp
  src/modules/processing_graph/topology/anthem_graph_node_port.h
  # src/modules/processing_graph/topology/anthem_graph_node_connection.cpp
  src/modules/processing_graph/topology/anthem_graph_node_connection.h
  src/modules/processing_graph/topology/anthem_graph_node.cpp
  src/modules/processing_graph/topology/anthem_graph_node.h
  src/modules/processing_graph/topology/anthem_graph_topology.cpp
  src/modules/processing_graph/topology/anthem_graph_topology.h
  
  src/modules/processing_graph/anthem_graph.cpp
  src/modules/processing_graph/anthem_graph.h

  ### Processors ###

  src/modules/processors/master_output_node.cpp
  src/modules/processors/master_output_node.h
  src/modules/processors/simple_volume_lfo_node.cpp
  src/modules/processors/simple_volume_lfo_node.h
  src/modules/processors/tone_generator_node.cpp
  src/modules/processors/tone_generator_node.h

  src/main.cpp
  src/plugin_window.cpp
  src/plugin_window.h

  ### Util ###

  src/modules/util/id_generator.cpp
  src/modules/util/id_generator.h
  src/modules/util/linear_parameter_smoother.cpp
  src/modules/util/linear_parameter_smoother.h
  src/modules/util/thread_safe_queue.h
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
  juce::juce_audio_processors
  juce::juce_audio_basics
  juce::juce_audio_devices

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
