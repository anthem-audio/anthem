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

use crate::model::song::Song;
use crate::util::id::get_id;
use rid::RidStore;

#[rid::store]
#[rid::structs(Project)]
#[derive(Debug)]
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

#[rid::model]
#[rid::structs(Song)]
#[derive(Clone, Debug)]
pub struct Project {
    pub id: u64,
    pub song: Song,
}

impl RidStore<Msg> for Store {
    fn create() -> Self {
        Self {
            // counter: Counter { count: 0 },
            projects: [
                Project {
                    id: 0,
                    song: Song::default(),
                },
                Project {
                    id: get_id(),
                    song: Song::default(),
                },
                Project {
                    id: get_id(),
                    song: Song::default(),
                },
            ]
            .to_vec(),
            active_project_id: 0,
        }
    }

    fn update(&mut self, /*req_id*/_: u64, msg: Msg) {
        match msg {
            Msg::NewProject => todo!(),
            Msg::SetActiveProject(_) => todo!(),
            Msg::CloseProject(_) => todo!(),
            Msg::AddPattern(_) => todo!(),
            Msg::DeletePattern(_) => todo!(),
        }
    }
}

#[rid::message(Reply)]
#[derive(Debug)]
pub enum Msg {
    NewProject,
    SetActiveProject(u64),
    CloseProject(u64),
    AddPattern(String),
    DeletePattern(u64),
}

#[rid::reply]
pub enum Reply {
    NewProjectCreated,
    ActiveProjectChanged,
    ProjectClosed,
    PatternAdded,
    PatternDeleted,
}
