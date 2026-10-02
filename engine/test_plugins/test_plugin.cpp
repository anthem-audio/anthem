/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#include <atomic>
#include <cmath>
#include <juce_audio_processors/juce_audio_processors.h>

namespace {

// A gain edit also changes opaque, non-parameter state. Cycling the gain back
// to its default must therefore still change the plugin's serialized state.
class RevisionGain final : public juce::AudioParameterFloat {
public:
  explicit RevisionGain(std::atomic<int>& revision)
    : AudioParameterFloat(juce::ParameterID("gain", 1),
          "Gain",
          juce::NormalisableRange<float>(0.0f, 1.0f, 0.0f),
          0.25f),
      revision(revision) {}
private:
  void valueChanged(float) override {
    revision.fetch_add(1, std::memory_order_relaxed);
  }

  std::atomic<int>& revision;
};

class TestPlugin final : public juce::AudioProcessor {
public:
  TestPlugin() : AudioProcessor(makeBuses()) {
    gain = new RevisionGain(stateRevision);
    invert = new juce::AudioParameterBool(juce::ParameterID("invert", 1), "Invert", false);
    addParameter(gain);
    addParameter(invert);
  }

  const juce::String getName() const override {
    return JucePlugin_Name;
  }
  bool acceptsMidi() const override {
    return ANTHEM_FIXTURE_INSTRUMENT;
  }
  bool producesMidi() const override {
    return false;
  }
  bool isMidiEffect() const override {
    return false;
  }
  double getTailLengthSeconds() const override {
    return 0.0;
  }
  int getNumPrograms() override {
    return 1;
  }
  int getCurrentProgram() override {
    return 0;
  }
  void setCurrentProgram(int) override {}
  const juce::String getProgramName(int) override {
    return "Default";
  }
  void changeProgramName(int, const juce::String&) override {}

  bool isBusesLayoutSupported(const BusesLayout& layout) const override {
    return layout.getMainOutputChannelSet() == juce::AudioChannelSet::stereo() &&
           (ANTHEM_FIXTURE_INSTRUMENT
                   ? layout.getMainInputChannelSet().isDisabled()
                   : layout.getMainInputChannelSet() == juce::AudioChannelSet::stereo());
  }

  void prepareToPlay(double sampleRate, int) override {
    rt_sampleRate = sampleRate;
    rt_phase = 0.0;
    rt_note = -1;
    rt_velocity = 0.0f;
  }
  void releaseResources() override {}
  using AudioProcessor::processBlock;

  void processBlock(juce::AudioBuffer<float>& audio, juce::MidiBuffer& midi) override {
    const float level = gain->get() * (invert->get() ? -1.0f : 1.0f);
    if (!ANTHEM_FIXTURE_INSTRUMENT) {
      audio.applyGain(level);
      midi.clear();
      return;
    }

    audio.clear();
    auto event = midi.begin();
    for (int sample = 0; sample < audio.getNumSamples(); ++sample) {
      while (event != midi.end() && (*event).samplePosition <= sample) {
        const auto message = (*event).getMessage();
        if (message.isNoteOn()) {
          rt_note = message.getNoteNumber();
          rt_velocity = message.getFloatVelocity();
          rt_phase = 0.0;
        } else if ((message.isNoteOff() && message.getNoteNumber() == rt_note) ||
                   message.isAllNotesOff() || message.isAllSoundOff()) {
          rt_note = -1;
        }
        ++event;
      }
      const float value = rt_note < 0 ? 0.0f : (rt_phase < 0.5 ? level : -level) * rt_velocity;
      for (int channel = 0; channel < audio.getNumChannels(); ++channel) {
        audio.setSample(channel, sample, value);
      }
      if (rt_note >= 0) {
        rt_phase += 440.0 * std::pow(2.0, (rt_note - 69) / 12.0) / rt_sampleRate;
        rt_phase -= std::floor(rt_phase);
      }
    }
    midi.clear();
  }

  bool hasEditor() const override {
    return true;
  }
  juce::AudioProcessorEditor* createEditor() override {
    return new juce::GenericAudioProcessorEditor(*this);
  }

  void getStateInformation(juce::MemoryBlock& data) override {
    auto object = new juce::DynamicObject();
    object->setProperty("formatVersion", 1);
    object->setProperty("gain", gain->get());
    object->setProperty("invert", invert->get());
    object->setProperty("revision", stateRevision.load(std::memory_order_relaxed));
    const auto json = juce::JSON::toString(juce::var(object), true);
    data.replaceAll(json.toRawUTF8(), json.getNumBytesAsUTF8());
  }

  void setStateInformation(const void* data, int size) override {
    const auto state =
        juce::JSON::parse(juce::String::fromUTF8(static_cast<const char*>(data), size));
    if (!state.isObject() || static_cast<int>(state["formatVersion"]) != 1) {
      return;
    }
    gain->setValueNotifyingHost(static_cast<float>(state["gain"]));
    invert->setValueNotifyingHost(static_cast<bool>(state["invert"]) ? 1.0f : 0.0f);
    stateRevision.store(static_cast<int>(state["revision"]), std::memory_order_relaxed);
  }
private:
  static BusesProperties makeBuses() {
    auto buses = BusesProperties();
    if (!ANTHEM_FIXTURE_INSTRUMENT) {
      buses = buses.withInput("Input", juce::AudioChannelSet::stereo(), true);
    }
    return buses.withOutput("Output", juce::AudioChannelSet::stereo(), true);
  }

  std::atomic<int> stateRevision{0};
  RevisionGain* gain = nullptr;
  juce::AudioParameterBool* invert = nullptr;
  double rt_sampleRate = 48000.0;
  double rt_phase = 0.0;
  int rt_note = -1;
  float rt_velocity = 0.0f;
};

} // namespace

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() {
  return new TestPlugin();
}
