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

#include "anthem.h"

Anthem::Anthem() {
    std::cout << "Initializing Tracktion Engine..." << std::endl;
    engine = std::unique_ptr<tracktion::Engine>(new tracktion::Engine("anthem"));

    std::cout << "Creating a new Tracktion project..." << std::endl;
    auto file = engine->getTemporaryFileManager().getTempDirectory().getChildFile ("temp_project").withFileExtension (tracktion::projectFileSuffix);
    tracktion::ProjectManager::TempProject tempProject (engine->getProjectManager(), file, true);
    project = tempProject.project;

    std::cout << "Initializing plugin manager..." << std::endl;
    auto& pluginManager = engine->getPluginManager();
    pluginManager.initialise();

    std::cout << "We can support " << pluginManager.pluginFormatManager.getNumFormats() << " plugin types:" << std::endl;
    for (auto format : pluginManager.pluginFormatManager.getFormats()) {
        std::cout << "   - " << format->getName() << std::endl;
    }
}
