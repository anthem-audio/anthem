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

#pragma once

#include "generated/lib/engine_api/messages/messages.h"

#include <juce_core/juce_core.h>
#include <rfl/json.hpp>
#include <string>
#include <utility>

namespace anthem {

class EngineApiMessageTest : public juce::UnitTest {
public:
  EngineApiMessageTest() : juce::UnitTest("EngineApiMessageTest", "Anthem") {}

  void runTest() override {
    testRenderAudioRequestParsesFromDartJson();
  }

  void testRenderAudioRequestParsesFromDartJson() {
    beginTest("RenderAudioRequest parses from Dart JSON");

    expectRenderAudioRequestParsesFormat("wav", RenderAudioFormat::wav);
    expectRenderAudioRequestParsesFormat("aiff", RenderAudioFormat::aiff);
    expectRenderAudioRequestParsesFormat("flac", RenderAudioFormat::flac);
    expectRenderAudioRequestParsesFormat("oggVorbis", RenderAudioFormat::oggVorbis);
  }

  void expectRenderAudioRequestParsesFormat(
      const std::string& formatJsonValue, RenderAudioFormat expectedFormat) {
    const auto requestJson =
        R"JSON({"id":982,"__type":"RenderAudioRequest","renderId":0,"outputPath":"C:\\Users\\qbgee\\Documents\\Renders\\first ever.wav","format":")JSON" +
        formatJsonValue + R"JSON(","startTick":0,"endTick":768,"includeTail":true})JSON";

    auto requestWrapped = rfl::json::read<Request>(requestJson);

    if (!requestWrapped.has_value()) {
      expect(false, requestWrapped.error().what());
      return;
    }

    auto request = std::move(requestWrapped.value());

    expect(rfl::holds_alternative<RenderAudioRequest>(request.variant()),
        "The request should parse as a RenderAudioRequest.");

    auto& renderAudioRequest = rfl::get<RenderAudioRequest>(request.variant());
    expectEquals(renderAudioRequest.requestBase.get().id, static_cast<int64_t>(982));
    expectEquals(renderAudioRequest.renderId, static_cast<int64_t>(0));
    expect(renderAudioRequest.format == expectedFormat,
        "The format should parse as " + formatJsonValue + ".");
    expectEquals(renderAudioRequest.startTick, static_cast<int64_t>(0));
    expectEquals(renderAudioRequest.endTick, static_cast<int64_t>(768));
    expect(renderAudioRequest.includeTail, "includeTail should parse as true.");
  }
};

static EngineApiMessageTest engineApiMessageTest;

} // namespace anthem
