/*
    Copyright (C) 2021 Joshua Wade

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

use crate::commands::command::Command;

pub struct CommandQueue {
    pub commands: Vec<Box<dyn Command>>,

    // Points to the next command for redo, or one past the end if there is
    // nothing to redo
    pub command_pointer: usize,
}

impl Default for CommandQueue {
    fn default() -> Self {
        CommandQueue {
            commands: Vec::new(),
            command_pointer: 0,
        }
    }
}

impl CommandQueue {
    pub fn push_command(&mut self, command: Box<dyn Command>) {
        while self.commands.len() > self.command_pointer {
            self.commands.pop();
        }
        self.commands.push(command);
        self.command_pointer += 1;
    }
    pub fn get_undo_and_bump_pointer(&mut self) -> Option<&Box<dyn Command>> {
        let command = self.commands.get(self.command_pointer - 1);
        if command.is_some() {
            self.command_pointer -= 1;
        }
        command
    }
    pub fn get_redo_and_bump_pointer(&mut self) -> Option<&Box<dyn Command>> {
        let command = self.commands.get(self.command_pointer);
        if command.is_some() {
            self.command_pointer += 1;
        }
        command
    }
}
