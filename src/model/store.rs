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

use rid::RidStore;
use serde::{Deserialize, Serialize};

use crate::commands::command::Command;
use crate::message_handlers::store_message_handler::store_message_handler;
use crate::message_handlers::pattern_message_handler::pattern_message_handler;
use crate::model::song::Song;
use crate::util::id::get_id;

#[rid::store]
#[rid::structs(Project)]
#[derive(Serialize, Deserialize)]
pub struct Store {
    pub projects: Vec<Project>,
    pub active_project_id: u64,
}

impl Store {
    pub fn get_project(&mut self, id: u64) -> &mut Project {
        self.projects
            .iter_mut()
            .find(|project| project.id == id)
            .expect("command references a non-existent project")
    }
}

fn default_file_path() -> String {
    "".to_string()
}

fn default_is_saved() -> bool {
    true
}

#[rid::model]
#[rid::structs(Song)]
#[derive(Serialize, Deserialize, rid::Config)]
pub struct Project {
    pub id: u64,

    // TODO: replace with Option<String> when rid gets option support
    #[serde(skip_serializing, default = "default_is_saved")]
    pub is_saved: bool,
    #[serde(skip_serializing, default = "default_file_path")]
    pub file_path: String,

    pub song: Song,

    #[serde(skip_serializing, skip_deserializing)]
    #[rid(skip)]
    pub commands: Vec<Box<dyn Command>>,

    // Points to the next command for redo, or one past the end if there is
    // nothing to redo
    #[serde(skip_serializing, skip_deserializing)]
    #[rid(skip)]
    pub command_pointer: usize,
}

impl Default for Project {
    fn default() -> Self {
        Project {
            id: get_id(),
            is_saved: false,
            file_path: "".into(),
            song: Song::default(),
            commands: Vec::new(),
            command_pointer: 0,
        }
    }
}

impl Project {
    pub fn push_command(&mut self, command: Box<dyn Command>) {
        while self.commands.len() > self.command_pointer {
            self.commands.pop();
        }
        self.commands.push(command);
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

impl RidStore<Msg> for Store {
    fn create() -> Self {
        let project = Project::default();
        let id = project.id;

        Self {
            projects: vec![project],
            active_project_id: id,
        }
    }

    fn update(&mut self, req_id: u64, msg: Msg) {
        let handled = [
            store_message_handler(self, req_id, &msg),
            pattern_message_handler(self, req_id, &msg),
        ]
        .iter()
        .fold(false, |a, b| a || *b);
        if !handled {
            panic!("message not handled");
        }
    }
}

#[rid::message(Reply)]
#[derive(Debug)]
pub enum Msg {
    // Store
    NewProject,
    SetActiveProject(u64),
    CloseProject(u64),
    SaveProject(u64, String),
    LoadProject(String),

    // Pattern
    AddPattern(u64, String),
    DeletePattern(u64, u64),
}

#[rid::reply]
#[derive(Clone, Debug)]
pub enum Reply {
    // Store
    NewProjectCreated(u64, String),
    ActiveProjectChanged(u64, String),
    ProjectClosed(u64),
    ProjectSaved(u64),
    ProjectLoaded(u64, String),

    // Pattern
    PatternAdded(u64),
    PatternDeleted(u64),
}
