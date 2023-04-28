/*
    Copyright (C) 2023 Joshua Wade

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

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <juce_audio_devices/juce_audio_devices.h>

#include <tracktion_engine/tracktion_engine.h>

#include <boost/interprocess/ipc/message_queue.hpp>

#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <cstdlib>

#include "messages_generated.h"
#include "open_message_queue.h"
#include "anthem.h"
#include "./command_handlers/project_command_handler.h"

using namespace boost::interprocess;

Anthem* anthem;

std::unique_ptr<message_queue> mqToUi;
std::unique_ptr<message_queue> mqFromUi;

volatile bool heartbeatOccurred = true;

// Checks for a recent heartbeat every 10 seconds. If there wasn't one, we exit
// the application.
void heartbeat() {
    while (true) {
        if (!heartbeatOccurred) {
            std::exit(0);
        }

        heartbeatOccurred = false;

        std::this_thread::sleep_for(std::chrono::seconds(10));
    }
}

std::thread messageLoopThread;

// Main loop that listens for messages from the UI and responds to them
void messageLoop() {
    auto idStr = juce::JUCEApplication::getCommandLineParameters();

    if (idStr.length() == 0) {
        std::cerr << "Engine ID was not provided. Exiting..." << std::endl;
        juce::JUCEApplication::quit();
        return;
    }

    auto mqToUiName = "engine-to-ui-" + idStr;
    auto mqFromUiName = "ui-to-engine-" + idStr;

    std::cout << "Creating engine-to-ui message queue" << std::endl;

    // Create a message_queue.
    mqToUi = std::unique_ptr<message_queue>(
        new message_queue(
            create_only,
            mqToUiName.toStdString().c_str(),

            // 100 messages can be in the queue at once
            100,

            // Each message can be a maximum of 65536 bytes (?) long
            65536));

    std::cout << "Opening ui-to-engine message queue" << std::endl;
    mqFromUi = openMessageQueue(mqFromUiName.toStdString().c_str());
    std::cout << "Opened successfully" << std::endl;

    std::thread heartbeat_thread(heartbeat);

    uint8_t buffer[65536];

    while (true) {
        std::size_t received_size;
        unsigned int priority;

        mqFromUi->receive(buffer, sizeof(buffer), received_size, priority);

        // Create a const pointer to the start of the buffer
        const void* send_buffer_ptr = static_cast<const void*>(buffer);

        // Get the root of the buffer
        auto request = flatbuffers::GetRoot<Request>(send_buffer_ptr);

        // Create flatbuffers builder
        auto builder = flatbuffers::FlatBufferBuilder();

        flatbuffers::Offset<void> return_value_offset;

        // Access the data in the buffer
        int request_id = request->id();
        auto command_type = request->command_type();
        std::optional<flatbuffers::Offset<Response>> response;
        switch (command_type) {
            case Command_Exit: {
                juce::JUCEApplication::quit();
                break;
            }
            case Command_Heartbeat: {
                heartbeatOccurred = true;
                auto heartbeatReply = CreateHeartbeatReply(builder);
                auto heartbeatReplyOffset = heartbeatReply.Union();
                response = std::optional(
                    CreateResponse(builder, request->id(), ReturnValue_HeartbeatReply, heartbeatReplyOffset)
                );
                break;
            }
            case Command_AddArrangement:
            case Command_AddGenerator:
            case Command_DeleteArrangement:
            case Command_GetPlugins:
                response = handleProjectCommand(request, builder, anthem);
                break;
            default: {
                std::cerr << "Received unknown command" << std::endl;
                break;
            }
        }

        if (response.has_value()) {
            builder.Finish(response.value());

            auto receive_buffer_ptr = builder.GetBufferPointer();
            auto buffer_size = builder.GetSize();

            // Send the response to the UI
            mqToUi->send(receive_buffer_ptr, buffer_size, 0);
        }
    }
}

class AnthemEngineApplication : public juce::JUCEApplicationBase, private juce::ChangeListener
{
private:
    void changeListenerCallback(juce::ChangeBroadcaster *source) override
    {
        std::cout << "change detected" << std::endl;
    }

public:
    AnthemEngineApplication() {}

    const juce::String getApplicationName() override { return "JUCE_APPLICATION_NAME_STRING"; }
    const juce::String getApplicationVersion() override { return "0.0.1"; }

    bool moreThanOneInstanceAllowed() override { return true; }

    void anotherInstanceStarted(const juce::String &commandLineParameters) override {}
    void suspended() override {}
    void resumed() override {}
    void shutdown() override {}

    void systemRequestedQuit() override
    {
        setApplicationReturnValue(0);
        quit();
    }

    void unhandledException(const std::exception *exception, const juce::String &sourceFilename,
                            int lineNumber) override
    {
        // This might not work
    }

    void initialise(const juce::String &commandLineParameters) override
    {
        std::cout << "Engine application start" << std::endl;
        anthem = new Anthem();

        // auto& pluginManager = anthem->engine->getPluginManager();
        // pluginManager.initialise();
        // pluginManager.pluginFormatManager.addDefaultFormats();

        messageLoop();
    }
};

START_JUCE_APPLICATION(AnthemEngineApplication);
