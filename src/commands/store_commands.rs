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

use std::fs;

use super::command::Command;
use crate::model::store::{Project, Reply, Store};

pub struct NewProjectCommand {
    pub project_id: u64,
}

impl Command for NewProjectCommand {
    fn execute(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        let project = Project::default();
        store.projects.push(project);
        vec![Reply::NewProjectCreated(
            request_id,
            (self.project_id as i64).to_string(),
        )]
    }

    // Undo doesn't make sense for this command
    fn rollback(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }
}

pub struct SetActiveProjectCommand {
    pub project_id: u64,
}

impl Command for SetActiveProjectCommand {
    fn execute(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        store.active_project_id = self.project_id;
        vec![Reply::ActiveProjectChanged(request_id)]
    }

    // Undo doesn't make sense for this command
    fn rollback(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }
}

pub struct CloseProjectCommand {
    pub project_id: u64,
}

impl Command for CloseProjectCommand {
    fn execute(&self, _store: &mut Store, request_id: u64) -> Vec<Reply> {
        _store
            .projects
            .retain(|project| project.id != self.project_id);
        vec![Reply::ProjectClosed(request_id)]
    }

    // Undo doesn't make sense for this command
    fn rollback(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }
}

pub struct SaveProjectCommand {
    pub project_id: u64,
    pub path: String,
}

impl Command for SaveProjectCommand {
    fn execute(&self, _store: &mut Store, request_id: u64) -> Vec<Reply> {
        let mut project = _store
            .projects
            .iter_mut()
            .find(|project| project.id == self.project_id)
            .expect("project does not exist");

        let serialized = serde_json::to_string(project).expect("project failed to serialize");

        fs::write(&self.path, &serialized).expect("unable to write to file");

        project.is_saved = true;

        vec![Reply::ProjectSaved(request_id)]
    }

    // Undo doesn't make sense for this command
    fn rollback(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }
}
