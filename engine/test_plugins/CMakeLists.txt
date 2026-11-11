# These fixtures use JUCE only; they do not link Anthem engine code.
function(anthem_add_test_plugin target synth code)
  juce_add_plugin(${target}
    VERSION 1.0.0
    COMPANY_NAME "Anthem Audio"
    BUNDLE_ID "audio.anthem.${target}"
    PLUGIN_MANUFACTURER_CODE Anth
    PLUGIN_CODE ${code}
    PRODUCT_NAME ${target}
    IS_SYNTH ${synth}
    NEEDS_MIDI_INPUT ${synth}
    NEEDS_MIDI_OUTPUT FALSE
    COPY_PLUGIN_AFTER_BUILD FALSE
    FORMATS VST3
  )
  target_sources(${target} PRIVATE test_plugin.cpp)
  target_compile_features(${target} PRIVATE cxx_std_20)
  target_compile_definitions(${target} PUBLIC
    ANTHEM_FIXTURE_INSTRUMENT=$<BOOL:${synth}>
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_DISABLE_JUCE_VERSION_PRINTING=1
  )
  target_link_libraries(${target} PRIVATE
    juce::juce_audio_processors
    juce::juce_recommended_config_flags
  )
endfunction()

anthem_add_test_plugin(AnthemTestInstrument TRUE Atsi)
anthem_add_test_plugin(AnthemTestEffect FALSE Atef)

# A native executable is needed for the startup-timeout test on every OS.
add_executable(AnthemUnconnectedTestEngine unconnected_engine.cpp)
target_compile_features(AnthemUnconnectedTestEngine PRIVATE cxx_std_20)
set_target_properties(AnthemUnconnectedTestEngine PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/helpers/$<CONFIG>"
)

add_custom_target(AnthemTestPlugins DEPENDS
  AnthemTestInstrument_VST3 AnthemTestEffect_VST3 AnthemUnconnectedTestEngine
)
