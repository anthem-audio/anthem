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

#include "project_command_handler.h"

std::optional<flatbuffers::Offset<Response>> handleProjectCommand(
    const Request* request,
    flatbuffers::FlatBufferBuilder& builder,
    Anthem* anthem
) {
    auto commandType = request->command_type();

    switch (commandType) {
        // TODO: Delete arrangement
        case Command_AddArrangement: {
            auto edit = tracktion::createEmptyEdit(*anthem->engine, juce::File("./I-dont-know-where-this-is-going.tracktion-edit"));

            // We store this pointer with the arrangement model in the UI, so
            auto editPtr = edit.release();

            auto editPtrAsUint = static_cast<uint64_t>(
                reinterpret_cast<uintptr_t>(editPtr)
            );

            auto response = CreateAddArrangementResponse(builder, editPtrAsUint);
            auto responseOffset = response.Union();

            auto message = CreateResponse(builder, request->id(), ReturnValue_AddArrangementResponse, responseOffset);

            return std::optional(message);
        }
        case Command_DeleteArrangement: {
            auto command = request->command_as_DeleteArrangement();
            auto edit = reinterpret_cast<tracktion::engine::Edit*>(
                static_cast<uintptr_t>(command->edit_pointer())
            );
            delete edit;

            return std::nullopt;
        }
        case Command_AddGenerator: {
            // Grab the plugin URI from the command
            auto command = request->command_as_AddGenerator();
            auto pluginUri = command->plugin_uri()->str();

            // Create a JUCE plugin description
            juce::PluginDescription pluginDescription;
            pluginDescription.fileOrIdentifier = pluginUri;
            pluginDescription.pluginFormatName = "VST3"; // Assume it's a VST3 for now

            // Instance the plugin
            juce::String errorMessage;
            auto pluginInstance = anthem->engine->getPluginManager().pluginFormatManager.createPluginInstance(
                pluginDescription,
                anthem->engine->getDeviceManager().getSampleRate(),
                anthem->engine->getDeviceManager().getBlockSize(),
                errorMessage
            );

            // TODO: Add a track?
            // anthem->engine

            return std::nullopt;
        }
        case Command_GetPlugins: {
            auto& pluginManager = anthem->engine->getPluginManager();

            auto plugins = pluginManager.knownPluginList.getTypes();

            std::vector<flatbuffers::Offset<flatbuffers::String>> fbPluginList;

            if (plugins.size() == 0) {
                fbPluginList.push_back(builder.CreateString("(:"));
            } else {
                for (auto plugin : plugins) {
                    fbPluginList.push_back(
                        builder.CreateString(
                            plugin.name.toStdString() + " - " + plugin.descriptiveName.toStdString()
                        )
                    );
                }
            }

            auto pluginListOffset = builder.CreateVector(fbPluginList);

            auto response = CreateGetPluginsResponse(builder, pluginListOffset);
            auto responseOffset = response.Union();

            auto message = CreateResponse(builder, request->id(), ReturnValue_GetPluginsResponse, responseOffset);

            return std::optional(message);
        }
        default: {
            std::cerr << "Unknown command received by handleProjectCommand()" << std::endl;
            return std::nullopt;
        }
    }
}
