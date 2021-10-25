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
use crate::commands::project_commands::*;
use crate::model::store::*;
use crate::util::id::get_id;
use crate::util::rid_reply_all::rid_reply_all;

pub fn project_message_handler(store: &mut Store, request_id: u64, msg: &Msg) -> bool {
    match msg {
        Msg::AddInstrument(project_id, name) => {
            let command = AddInstrumentCommand {
                id: get_id(),
                name: name.clone(),
            };
            let replies = command.execute(store.get_project_mut(*project_id), request_id);
            store
                .command_queues
                .get_mut(project_id)
                .unwrap()
                .push_command(Box::new(command));
            rid_reply_all(&replies);
        }
        Msg::AddController(project_id, name) => {
            let command = AddControllerCommand {
                id: get_id(),
                name: name.clone(),
            };
            let replies = command.execute(store.get_project_mut(*project_id), request_id);
            store
                .command_queues
                .get_mut(project_id)
                .unwrap()
                .push_command(Box::new(command));
            rid_reply_all(&replies);
        }
        Msg::RemoveGenerator(_project_id, _generator_id) => {
            todo!();
        }
        _ => {
            return false;
        }
    }
    true
}
