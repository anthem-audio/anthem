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

use crate::util::id::get_id;
use rid::RidStore;

#[rid::store]
#[rid::structs(Project)]
#[derive(Debug)]
pub struct Store {
    projects: Vec<Project>,
    active_project_id: u64,
}

// #[rid::model]
// #[derive(Debug)]
// pub struct Counter {
//     count: u32,
// }

#[rid::model]
#[derive(Clone, Debug)]
pub struct Project {
    id: u64,
}

impl RidStore<Msg> for Store {
    fn create() -> Self {
        Self {
            // counter: Counter { count: 0 },
            projects: [
                Project { id: 0 },
                Project { id: get_id() },
                Project { id: get_id() },
            ]
            .to_vec(),
            active_project_id: 0,
        }
    }

    fn update(&mut self, req_id: u64, msg: Msg) {
        match msg {
            Msg::NewProject => {
                self.projects.push(Project { id: get_id() });
                rid::post(Reply::NewProjectCreated(req_id))
            }
            Msg::SetActiveProject(project_id) => {
                self.active_project_id = project_id;
                rid::post(Reply::ActiveProjectChanged(req_id))
            }
        }
    }
}

#[rid::message(Reply)]
#[derive(Debug)]
pub enum Msg {
    NewProject,
    SetActiveProject(u64),
    // Inc,
    // Add(u32),
}

#[rid::reply]
pub enum Reply {
    NewProjectCreated(u64),
    ActiveProjectChanged(u64),
    // Increased(u64),
    // Added(u64, String),
}
