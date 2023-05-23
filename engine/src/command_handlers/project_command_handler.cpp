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
            // we need to extract it from the unique_ptr.
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
        case Command_AddPlugin: {
            auto errorResponse = CreateAddPluginResponse(builder, false);
            auto errorResponseOffset = errorResponse.Union();
            auto errorResponseMessage = CreateResponse(builder, request->id(), ReturnValue_AddPluginResponse, errorResponseOffset);

            auto& pluginManager = anthem->engine->getPluginManager();
            
            // Grab the plugin URI from the command
            auto command = request->command_as_AddPlugin();
            auto pluginUri = command->plugin_uri()->str();

            juce::OwnedArray<juce::PluginDescription> typesFound;

            std::cout << "Scanning the plugin..." << std::endl;

            // Scan the plugin
            pluginManager.knownPluginList.scanAndAddFile(
                pluginUri,
                true,
                typesFound,
                *pluginManager.pluginFormatManager.getFormat(0) // We just support VST3 for now
            );

            std::cout << "Scanned plugin." << std::endl;

            if (typesFound.size() == 0) {
                std::cout << "Plugin scan didn't identify the plugin as valid." << std::endl;
                return std::optional(errorResponseMessage);
            }

            auto edit = reinterpret_cast<tracktion::engine::Edit*>(
                static_cast<uintptr_t>(command->edit_pointer())
            );

            auto pluginInstance = edit->getPluginCache().createNewPlugin(
                tracktion::ExternalPlugin::xmlTypeName,
                *typesFound[0]
            );

            if (pluginInstance) {
                // Get a reference to the main track list
                auto& trackList = edit->getTrackList();

                // Create the TrackInsertPoint
                tracktion::TrackInsertPoint tip(nullptr, nullptr); // Always inserts at the start - TODO figure this out lol

                // Insert the new audio track
                auto newTrack = edit->insertNewAudioTrack(tip, nullptr);

                newTrack->pluginList.insertPlugin(pluginInstance, -1, nullptr);

                auto processor = pluginInstance->getWrappedAudioProcessor();

                // Create a window manually, since Tracktion doesn't seem to want to open an external plugin window
                auto window = new PluginWindow(processor); // TODO ha ha this is bad
                window->setVisible(true);

                window->setTopLeftPosition(juce::Point(10, 10));

                std::cout << "Loaded plugin: " << pluginInstance->getName() << std::endl;
            } else {
                std::cout << "Error adding plugin";
                return std::optional(errorResponseMessage);
            }

            auto response = CreateAddPluginResponse(builder, true);
            auto responseOffset = response.Union();

            auto message = CreateResponse(builder, request->id(), ReturnValue_AddPluginResponse, responseOffset);

            return std::optional(message);
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
