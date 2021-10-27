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

use std::collections::HashMap;

use rid::RidStore;

use crate::commands::command::Command;
use crate::message_handlers::pattern_message_handler::pattern_message_handler;
use crate::message_handlers::project_message_handler::project_message_handler;
use crate::message_handlers::store_message_handler::store_message_handler;

use crate::model::project::Project;

use super::command_queue::CommandQueue;

#[rid::store]
#[rid::structs(Project)]
#[derive(rid::Config)]
pub struct Store {
    pub projects: Vec<Project>,
    pub active_project_id: u64,

    #[rid(skip)]
    pub command_queues: HashMap<u64, CommandQueue>,
}

impl Store {
    pub fn get_project(&self, id: u64) -> &Project {
        self.projects
            .iter()
            .find(|project| project.id == id)
            .expect("command references a non-existent project")
    }
    pub fn get_project_mut(&mut self, id: u64) -> &mut Project {
        self.projects
            .iter_mut()
            .find(|project| project.id == id)
            .expect("command references a non-existent project")
    }
    pub fn push_command(&mut self, project_id: u64, command: Box<dyn Command>) {
        self
            .command_queues
            .get_mut(&project_id)
            .unwrap()
            .push_command(command);
    }
}

impl RidStore<Msg> for Store {
    fn create() -> Self {
        let project = Project::default();
        let id = project.id;
        let mut command_queues = HashMap::new();
        command_queues.insert(id, CommandQueue::default());

        Self {
            projects: vec![project],
            active_project_id: id,
            command_queues,
        }
    }

    fn update(&mut self, req_id: u64, msg: Msg) {
        let handled = [
            store_message_handler(self, req_id, &msg),
            project_message_handler(self, req_id, &msg),
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
    Undo(u64),
    Redo(u64),

    // Project
    AddInstrument(u64, String),
    AddController(u64, String),
    RemoveGenerator(u64, u64),
    SetActivePattern(u64, u64), // 0 means none
    SetActiveInstrument(u64, u64), // 0 means none
    SetActiveController(u64, u64), // 0 means none

    // Pattern
    AddPattern(u64, String),
    DeletePattern(u64, u64),
    AddNote(u64, u64, u64, String),
    DeleteNote(u64, u64, u64, u64),
}

// TODO: Some commands are destructive beyond what they can repair,
// specifically pattern and generator removal as of writing.

#[rid::reply]
#[derive(Clone, Debug)]
pub enum Reply {
    // Store
    NewProjectCreated(u64, String),
    ActiveProjectChanged(u64, String),
    ProjectClosed(u64),
    ProjectSaved(u64),
    ProjectLoaded(u64, String),

    // Project
    InstrumentAdded(u64),
    ControllerAdded(u64),
    GeneratorRemoved(u64),
    ActivePatternSet(u64),
    ActiveInstrumentSet(u64),
    ActiveControllerSet(u64),

    // Pattern
    PatternAdded(u64),
    PatternDeleted(u64),
    NoteAdded(u64),
    NoteDeleted(u64),
}
