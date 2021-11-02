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

use crate::model::command_queue::CommandQueue;
use crate::model::project::*;
use crate::model::store::*;
use crate::util::rid_reply_all::rid_reply_all;

pub fn store_message_handler(store: &mut Store, request_id: u64, msg: &Msg) -> bool {
    match msg {
        Msg::NewProject => {
            let project = Project::default();
            let project_id = project.id;
            store.projects.insert(project.id, project);
            store.project_order.push(project_id);
            store
                .command_queues
                .insert(project_id, CommandQueue::default());
            rid::post(Reply::NewProjectCreated(
                request_id,
                (project_id as i64).to_string(),
            ));
        }
        Msg::SetActiveProject(project_id) => {
            store.active_project_id = *project_id;
            rid::post(Reply::ActiveProjectChanged(
                request_id,
                (*project_id as i64).to_string(),
            ));
        }
        Msg::CloseProject(project_id) => {
            store.projects.remove(project_id);
            store.project_order.retain(|id| *id != *project_id);
            store.command_queues.remove(project_id);
            rid::post(Reply::ProjectClosed(request_id));
        }
        Msg::SaveProject(project_id, path) => {
            let mut project = store
                .projects
                .get_mut(project_id)
                .expect("project does not exist");

            let serialized = serde_json::to_string(project).expect("project failed to serialize");

            fs::write(path, &serialized).expect("unable to write to file");

            project.is_saved = true;

            rid::post(Reply::ProjectSaved(request_id));
        }
        Msg::LoadProject(path) => {
            let project_raw = fs::read_to_string(path).expect("project path does not exist");
            let mut project: Project = serde_json::from_str(&project_raw).expect("invalid project");

            let id = project.id;
            project.file_path = path.clone();

            store.projects.insert(project.id, project);
            store.project_order.push(id);

            rid::post(Reply::ProjectLoaded(request_id, (id as i64).to_string()));
        }
        Msg::Undo(project_id) => {
            let command = store
                .command_queues
                .get_mut(project_id)
                .unwrap()
                .get_undo_and_bump_pointer();
            let project = store
                .projects
                .get_mut(project_id)
                .expect("command references a non-existent project");

            if command.is_some() {
                let command = command.unwrap().as_ref();

                let replies = command.rollback(project, request_id);

                rid_reply_all(&replies);
            } else {
                rid::post(Reply::NothingChanged(request_id));
            }
        }
        Msg::Redo(project_id) => {
            let command = store
                .command_queues
                .get_mut(project_id)
                .unwrap()
                .get_redo_and_bump_pointer();
            let project = store
                .projects
                .get_mut(project_id)
                .expect("command references a non-existent project");

            if command.is_some() {
                let command = command.unwrap().as_ref();

                let replies = command.execute(project, request_id);

                rid_reply_all(&replies);
            } else {
                rid::post(Reply::NothingChanged(request_id));
            }
            }
        }
        _ => {
            return false;
        }
    };
    true
}
