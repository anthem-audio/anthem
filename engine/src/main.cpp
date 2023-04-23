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

#include "messages_generated.h"
#include "open_message_queue.h"

using namespace boost::interprocess;

int main() {
    std::cout << "Creating engine-to-ui message queue" << std::endl;

    // Create a message_queue.
    auto mqToUi = std::unique_ptr<message_queue>(
        new message_queue(
            create_only,
            "engine-to-ui",

            // 100 messages can be in the queue at once
            100,

            // Each message can be a maximum of 65536 bytes (?) long
            65536));

    std::cout << "Opening ui-to-engine message queue" << std::endl;
    auto mqFromUi = openMessageQueue("ui-to-engine");
    std::cout << "Opened successfully" << std::endl;

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
        int a, b;
        ReturnValue return_value_type;
        switch (command_type) {
            case Command_Add: {
                auto add = request->command_as_Add();
                a = add->a();
                b = add->b();
                std::cout << "Received Add command: " << a << " + " << b << std::endl;
                auto add_return_value = CreateAddReturnValue(builder, a + b);
                return_value_offset = add_return_value.Union();
                return_value_type = ReturnValue_AddReturnValue;
                break;
            }
            case Command_Subtract: {
                auto subtract = request->command_as_Subtract();
                a = subtract->a();
                b = subtract->b();
                std::cout << "Received Subtract command: " << a << " - " << b << std::endl;
                auto subtract_return_value = CreateSubtractReturnValue(builder, a - b);
                return_value_offset = subtract_return_value.Union();
                return_value_type = ReturnValue_SubtractReturnValue;
                break;
            }
            case Command_Exit: {
                return 0;
            }
            // Handle other commands here
            default: {
                std::cerr << "Received unknown command" << std::endl;
                break;
            }
        }

        // Create the response object
        auto response = CreateResponse(builder, request_id, return_value_type, return_value_offset);

        builder.Finish(response);

        auto receive_buffer_ptr = builder.GetBufferPointer();
        auto buffer_size = builder.GetSize();

        // Send the response to the UI
        mqToUi->send(receive_buffer_ptr, buffer_size, 0);
    }

    return 0;
}
