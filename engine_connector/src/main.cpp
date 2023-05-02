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

#include <boost/interprocess/ipc/message_queue.hpp>
#include <iostream>
#include <vector>

#include "open_message_queue.h"

using namespace boost::interprocess;

#ifdef _WIN32
    #define DYLIB_EXPORT __declspec(dllexport)
    #define CALL_CONV __stdcall
#else
    #define DYLIB_EXPORT __attribute__((visibility("default")))
    #define CALL_CONV
#endif

struct EngineConnection {
    // ID of the connection
    int64_t id;

    // Message queue for sending mesasges to the engine
    std::unique_ptr<boost::interprocess::message_queue> mqToEngine;

    // Message queue for receiving mesasges from the engine
    std::unique_ptr<boost::interprocess::message_queue> mqFromEngine;

    // Buffer for receiving messages from the server process
    uint8_t *message_receive_buffer = new uint8_t[65536];

    // Buffer for sending messages to the server process
    uint8_t *message_send_buffer = new uint8_t[65536];

    // Size of the last message that was received from the engine
    std::size_t last_received_size;

    // Priority of the last message that was received from the engine
    unsigned int last_received_priority;
};

// We have multiple EngineConnector classes in Dart, but they all effectively
// use the same DLL, as any memory here is shared between these classes. This
// vector stores data for each Dart EngineConnection class.
std::vector<std::unique_ptr<EngineConnection>> engineConnections;

EngineConnection& getEngineConnection(int64_t id) {
    for (auto& connection : engineConnections) {
        if (connection->id == id) {
            return *connection;
        }
    }
    throw std::runtime_error("EngineConnection not found for the given id");
}

extern "C"
{
    DYLIB_EXPORT void CALL_CONV cleanUpMessageQueues(int64_t engineID)
    {
        std::string engineIdStr = std::to_string(engineID);
        auto mqToEngineName = "ui-to-engine-" + engineIdStr;
        auto mqFromEngineName = "engine-to-ui-" + engineIdStr;

        message_queue::remove(mqToEngineName.c_str());
        message_queue::remove(mqFromEngineName.c_str());
    }

    DYLIB_EXPORT void CALL_CONV connect(int64_t engineID)
    {
        auto engineConnection = std::make_unique<EngineConnection>();

        engineConnection->id = engineID;

        std::string engineIdStr = std::to_string(engineID);
        auto mqToEngineName = "ui-to-engine-" + engineIdStr;
        auto mqFromEngineName = "engine-to-ui-" + engineIdStr;

        // Create a message_queue.
        engineConnection->mqToEngine = std::unique_ptr<message_queue>(
            new message_queue(
                create_only,
                mqToEngineName.c_str(),

                // 100 messages can be in the queue at once
                100,

                // Each message can be a maximum of 65536 bytes (?) long
                65536));

        std::cout << "Opening engine-to-ui message queue..." << std::endl;
        engineConnection->mqFromEngine = openMessageQueue(mqFromEngineName.c_str());
        std::cout << "Opened successfully." << std::endl;

        engineConnections.push_back(std::move(engineConnection));
    }

    DYLIB_EXPORT void CALL_CONV freeEngineConnection(int64_t engineID)
    {
        int index;
        bool found = false;

        for (int i = 0; i < engineConnections.size(); i++) {
            auto& connection = engineConnections[i];
            if (connection->id == engineID) {
                index = i;
                found = true;
                break;
            }
        }

        if (!found) {
            throw std::runtime_error("EngineConnection not found for the given id");
        }

        engineConnections.erase(engineConnections.begin() + index);
    }

    DYLIB_EXPORT uint8_t *CALL_CONV getMessageSendBuffer(int64_t engineID)
    {
        auto& engineConnection = getEngineConnection(engineID);
        return engineConnection.message_send_buffer;
    }

    DYLIB_EXPORT uint8_t *CALL_CONV getMessageReceiveBuffer(int64_t engineID)
    {
        auto& engineConnection = getEngineConnection(engineID);
        return engineConnection.message_receive_buffer;
    }

    DYLIB_EXPORT std::size_t CALL_CONV getLastReceivedMessageSize(int64_t engineID)
    {
        auto& engineConnection = getEngineConnection(engineID);
        return engineConnection.last_received_size;
    }

    DYLIB_EXPORT void CALL_CONV sendFromBuffer(int64_t engineID, int64_t size)
    {
        auto& engineConnection = getEngineConnection(engineID);
        engineConnection.mqToEngine->send(engineConnection.message_send_buffer, size, 0);
    }

    // This blocks the current thread until a message is received.
    DYLIB_EXPORT bool CALL_CONV receive(int64_t engineID)
    {
        try {
            auto& engineConnection = getEngineConnection(engineID);
            engineConnection.mqFromEngine->receive(
                engineConnection.message_receive_buffer,
                65536,
                engineConnection.last_received_size,
                engineConnection.last_received_priority
            );
            return true;
        }
        catch (const interprocess_exception &ex) {
            std::cerr << "Error receiving message: " << ex.what() << std::endl;
            return false;
        }
        catch (const std::exception &ex) {
            std::cerr << "Error: " << ex.what() << std::endl;
            return false;
        }
    }

    DYLIB_EXPORT bool CALL_CONV tryReceive(int64_t engineID)
    {
        try {
            auto& engineConnection = getEngineConnection(engineID);
            return engineConnection.mqFromEngine->try_receive(
                engineConnection.message_receive_buffer,
                65536,
                engineConnection.last_received_size,
                engineConnection.last_received_priority
            );
        }
        catch (const interprocess_exception &ex) {
            std::cerr << "Error receiving message: " << ex.what() << std::endl;
            return false;
        }
        catch (const std::exception &ex) {
            std::cerr << "Error: " << ex.what() << std::endl;
            return false;
        }
    }
}
