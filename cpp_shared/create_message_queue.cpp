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

#include "create_message_queue.h"

std::unique_ptr<message_queue> openMessageQueue(const char *name)
{
    int count = 0;

    while (true)
    {
        count++;

        try
        {
            // Open a message_queue.
            return std::unique_ptr<message_queue>(
                new message_queue(
                    open_only,
                    name));
        }
        catch (...)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        if (count > 100)
        {
            throw std::runtime_error("Failed to open message queue.");
        }
    }
}
