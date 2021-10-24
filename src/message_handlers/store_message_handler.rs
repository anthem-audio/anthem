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
use crate::commands::store_commands::*;
use crate::util::rid_reply_all::rid_reply_all;
use crate::model::store::*;

pub fn store_message_handler(store: &mut Store, req_id: u64, msg: &Msg) -> bool {
    match msg {
        Msg::NewProject => {
            let replies = NewProjectCommand.execute(store, req_id);

            rid_reply_all(&replies);
        }
        Msg::SetActiveProject(project_id) => {
            let replies = (SetActiveProjectCommand {
                project_id: *project_id,
            })
            .execute(store, req_id);

            rid_reply_all(&replies);
        }
        Msg::CloseProject(project_id) => {
            let replies = (CloseProjectCommand {
                project_id: *project_id,
            })
            .execute(store, req_id);

            rid_reply_all(&replies);
        }
        Msg::SaveProject(project_id, path) => {
            let replies = (SaveProjectCommand {
                project_id: *project_id,
                path: (*path).clone(),
            })
            .execute(store, req_id);

            rid_reply_all(&replies);
        }
        Msg::LoadProject(path) => {
            let replies = (LoadProjectCommand {
                path: (*path).clone(),
            })
            .execute(store, req_id);

            rid_reply_all(&replies);
        }
        _ => {
            return false;
        }
    };
    true
}
