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
    engine = std::unique_ptr<tracktion::Engine>(new tracktion::Engine("anthem"));

    auto& pluginManager = engine->getPluginManager();

    // Set up JUCE to be able to scan and load plugins of all supported plugin formats
    pluginManager.pluginFormatManager.addDefaultFormats();

    std::cout << "We can support " << pluginManager.pluginFormatManager.getNumFormats() << " plugin types:" << std::endl;
    for (auto format : pluginManager.pluginFormatManager.getFormats()) {
        std::cout << "   - " << format->getName() << std::endl;
    }
}
