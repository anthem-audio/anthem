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

use crate::commands::project_commands::*;
use crate::model::store::*;
use crate::util::execute_and_push::*;
use crate::util::id::*;

pub fn project_message_handler(store: &mut Store, request_id: u64, msg: &Msg) -> bool {
    match msg {
        Msg::AddInstrument(project_id, name) => {
            let command = AddInstrumentCommand {
                id: get_id(),
                name: name.clone(),
            };
            execute_and_push(store, request_id, *project_id, Box::new(command));
        }
        Msg::AddController(project_id, name) => {
            let command = AddControllerCommand {
                id: get_id(),
                name: name.clone(),
            };
            execute_and_push(store, request_id, *project_id, Box::new(command));
        }
        Msg::RemoveGenerator(_project_id, _generator_id) => {
            todo!();
        }
        Msg::SetActivePattern(project_id, pattern_id) => {
            store.get_project_mut(*project_id).song.active_pattern_id = *pattern_id;
            rid::post(Reply::ActivePatternSet(request_id));
        }
        _ => {
            return false;
        }
    }
    true
}
