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

use super::command::Command;
use crate::model::{
    song::Song,
    store::{Project, Reply, Store},
};

pub struct NewProjectCommand {
    pub project_id: u64,
}

impl Command for NewProjectCommand {
    fn execute(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        let project = Project {
            id: self.project_id,
            song: Song::default(),
        };
        store.projects.push(project);
        vec![Reply::NewProjectCreated(request_id)]
    }

    // The new project command should not be part of the undo list
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

    // The set active project command should not be part of the undo list
    fn rollback(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }
}

pub struct CloseProjectCommand {
    pub project_id: u64,
}

impl Command for CloseProjectCommand {
    fn execute(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }

    // The set active project command should not be part of the undo list
    fn rollback(&self, _store: &mut Store, _request_id: u64) -> Vec<Reply> {
        unimplemented!()
    }
}
