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

#include "plugin_window.h"

PluginWindow::PluginWindow(juce::AudioProcessor* processor)
    : DocumentWindow(processor->getName(),
                     juce::Colours::lightgrey,
                     juce::DocumentWindow::allButtons)
{
    auto* editor = processor->createEditorIfNeeded();
    if (editor != nullptr)
    {
        setContentOwned(editor, true);
        setResizable(false, false);
        setUsingNativeTitleBar(true);
        setSize(editor->getWidth(), editor->getHeight());
        centreWithSize(getWidth(), getHeight());
    }
    else
    {
        jassertfalse; // The plugin should have a valid editor
    }
}

PluginWindow::~PluginWindow()
{
    // Make sure to remove the editor and release the plugin instance
    setContentOwned(nullptr, true);
}

void PluginWindow::closeButtonPressed()
{
    setVisible(false);
}
