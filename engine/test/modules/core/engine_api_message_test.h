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
    testMessageRolesParseFromDartJson();
  }

  void testMessageRolesParseFromDartJson() {
    beginTest("Shared message union parses requests, responses and events with flat tags");
    const auto request =
        rfl::json::read<IpcMessage>(R"({"id":0,"__type":"TestUiEchoRequest","value":"hello"})");
    expect(request.has_value());
    if (request) {
      const auto& echo = rfl::get<TestUiEchoRequest>(request.value().variant());
      expectEquals(echo.requestBase.get().id, int64_t{0});
      expectEquals(echo.value, std::string("hello"));
      const auto category = rfl::json::read<Request>(rfl::json::write(request.value()));
      expect(category.has_value());
    }
    const auto reply = rfl::json::read<IpcMessage>(
        R"({"id":0,"__type":"RequestErrorResponse","code":"failed","message":"write failed"})");
    expect(reply.has_value());
    if (reply) {
      const auto& error = rfl::get<RequestErrorResponse>(reply.value().variant());
      expectEquals(error.responseBase.get().id, int64_t{0});
      expect(error.code == RequestErrorCode::failed);
      expectEquals(error.message, std::string("write failed"));
      expect(rfl::json::read<Response>(rfl::json::write(reply.value())).has_value());
    }
    const auto event = rfl::json::read<IpcMessage>(
        R"({"__type":"AudioSessionInvalidatedEvent","reason":"device disconnected"})");
    expect(event.has_value());
    if (event) {
      const auto& invalidated = rfl::get<AudioSessionInvalidatedEvent>(event.value().variant());
      expect(invalidated.reason == std::optional<std::string>("device disconnected"));
      const auto json = rfl::json::write(event.value());
      expect(json.find("\"id\"") == std::string::npos);
      expect(rfl::json::read<IpcEvent>(json).has_value());
      expect(!rfl::json::read<Response>(json).has_value());
    }
  }

  void testRenderAudioRequestParsesFromDartJson() {
    beginTest("RenderAudioRequest parses from Dart JSON");

    expectRenderAudioRequestParsesFormat("wav", RenderAudioFormat::wav);
    expectRenderAudioRequestParsesFormat("aiff", RenderAudioFormat::aiff);
    expectRenderAudioRequestParsesFormat("flac", RenderAudioFormat::flac);
    expectRenderAudioRequestParsesFormat("oggVorbis", RenderAudioFormat::oggVorbis);
    expectRenderAudioRequestParsesFormat("mp3", RenderAudioFormat::mp3);
  }

  void expectRenderAudioRequestParsesFormat(
      const std::string& formatJsonValue, RenderAudioFormat expectedFormat) {
    const auto requestJson =
        R"JSON({"id":982,"__type":"RenderAudioRequest","renderId":0,"outputPath":"C:\\Users\\qbgee\\Documents\\Renders\\first ever.wav","format":")JSON" +
        formatJsonValue +
        R"JSON(","startTick":0,"endTick":768,"includeTail":true,"bitDepth":32,"qualityOptionIndex":9,"sampleFormat":"floatingPoint"})JSON";

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
    expectEquals(renderAudioRequest.bitDepth, static_cast<int64_t>(32));
    expectEquals(renderAudioRequest.qualityOptionIndex, static_cast<int64_t>(9));
    expect(renderAudioRequest.sampleFormat == RenderAudioSampleFormat::floatingPoint,
        "sampleFormat should parse as floatingPoint.");
  }
};

static EngineApiMessageTest engineApiMessageTest;

} // namespace anthem
