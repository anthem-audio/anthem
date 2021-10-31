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

use crate::commands::pattern_commands::*;
use crate::model::note::*;
use crate::model::pattern::*;
use crate::model::store::*;
use crate::util::execute_and_push::*;

pub fn pattern_message_handler(store: &mut Store, request_id: u64, msg: &Msg) -> bool {
    match msg {
        Msg::AddPattern(project_id, pattern_name) => {
            let command = AddPatternCommand {
                project_id: *project_id,
                pattern: Pattern::new(pattern_name.clone()),
                index: store
                    .projects
                    .iter()
                    .find(|project| project.id == *project_id)
                    .unwrap()
                    .song
                    .pattern_order
                    .len(),
            };
            execute_and_push(store, request_id, *project_id, Box::new(command));
        }
        Msg::DeletePattern(project_id, pattern_id) => {
            let project = store.get_project_mut(*project_id);
            let patterns = &mut project.song.patterns;

            let command = DeletePatternCommand {
                project_id: *project_id,
                pattern: patterns.get(pattern_id).unwrap().clone(),
                index: store
                    .projects
                    .iter()
                    .find(|project| project.id == *project_id)
                    .unwrap()
                    .song
                    .pattern_order
                    .iter()
                    .position(|id| *id == *pattern_id)
                    .unwrap(),
            };

            execute_and_push(store, request_id, *project_id, Box::new(command));
        }
        Msg::AddNote(project_id, pattern_id, instrument_id, note_json) => {
            let note: Note = serde_json::from_str(note_json).unwrap();

            let command = AddNoteCommand {
                project_id: *project_id,
                pattern_id: *pattern_id,
                generator_id: *instrument_id,
                note,
            };

            execute_and_push(store, request_id, *project_id, Box::new(command));
        }
        _ => {
            return false;
        }
    }
    true
}
