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
use crate::commands::pattern_commands::*;
use crate::model::note::*;
use crate::model::pattern::*;
use crate::model::store::*;
use crate::util::rid_reply_all::rid_reply_all;

pub fn pattern_message_handler(store: &mut Store, request_id: u64, msg: &Msg) -> bool {
    match msg {
        Msg::AddPattern(project_id, pattern_name) => {
            let command = AddPatternCommand {
                project_id: *project_id,
                pattern: Pattern::new(pattern_name.clone()),
            };
            command.execute(store.get_project_mut(*project_id), request_id);
            store
                .command_queues
                .get_mut(project_id)
                .unwrap()
                .push_command(Box::new(command));
            rid_reply_all(&vec![Reply::PatternAdded(request_id)]);
        }
        Msg::DeletePattern(project_id, pattern_id) => {
            let project = store.get_project_mut(*project_id);
            let patterns = &mut project.song.patterns;

            let command = DeletePatternCommand {
                project_id: *project_id,
                pattern: patterns.remove(
                    patterns
                        .iter()
                        .position(|pattern| pattern.id == *pattern_id)
                        .expect("pattern delete: requested pattern could not be found"),
                ),
            };

            let replies = command.execute(store.get_project_mut(*project_id), request_id);
            store.push_command(*project_id, Box::new(command));

            rid_reply_all(&replies);
        }
        Msg::AddNote(project_id, pattern_id, instrument_id, note_json) => {
            let project = store.get_project_mut(*project_id);

            let note: Note = serde_json::from_str(note_json).unwrap();

            let command = AddNoteCommand {
                project_id: *project_id,
                pattern_id: *pattern_id,
                channel_id: *instrument_id,
                note,
            };

            let replies = command.execute(project, request_id);
            store.push_command(*project_id, Box::new(command));

            rid_reply_all(&replies);
        }
        _ => {
            return false;
        }
    }
    true
}
