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
use crate::commands::store_commands::*;
use crate::model::song::Song;
use crate::util::id::get_id;
use crate::util::rid_reply_all::rid_reply_all;

#[rid::store]
#[rid::structs(Project)]
#[derive(Debug, Serialize, Deserialize)]
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
#[derive(Debug, Serialize, Deserialize)]
pub struct Project {
    pub id: u64,

    // TODO: replace with Option<String> when rid gets option support
    #[serde(skip_serializing, default = "default_is_saved")]
    pub is_saved: bool,
    #[serde(skip_serializing, default = "default_file_path")]
    pub file_path: String,

    pub song: Song,
}

impl Default for Project {
    fn default() -> Self {
        Project {
            id: get_id(),
            is_saved: false,
            file_path: "".into(),
            song: Song::default(),
        }
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
        match msg {
            Msg::NewProject => {
                let replies = NewProjectCommand.execute(self, req_id);

                rid_reply_all(&replies);
            }
            Msg::SetActiveProject(project_id) => {
                let replies = (SetActiveProjectCommand { project_id }).execute(self, req_id);

                rid_reply_all(&replies);
            }
            Msg::CloseProject(project_id) => {
                let replies = (CloseProjectCommand { project_id }).execute(self, req_id);

                rid_reply_all(&replies);
            }
            Msg::SaveProject(project_id, path) => {
                let replies = (SaveProjectCommand { project_id, path }).execute(self, req_id);

                rid_reply_all(&replies);
            }
            Msg::LoadProject(path) => {
                let replies = (LoadProjectCommand { path }).execute(self, req_id);

                rid_reply_all(&replies);
            }

            Msg::AddPattern(_) => {}
            Msg::DeletePattern(_) => {}
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
    AddPattern(String),
    DeletePattern(u64),
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
