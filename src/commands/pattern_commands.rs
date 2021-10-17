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
use crate::model::pattern::Pattern;
use crate::model::store::{Reply, Store};

pub struct AddPatternCommand {
    pattern_id: u64,
    project_id: u64,
    name: String,
}

impl Command for AddPatternCommand {
    fn execute(&self, store: &mut Store) -> Vec<Reply> {
        let pattern = Pattern {
            id: self.pattern_id,
            name: self.name.clone(),
        };
        let project = store.get_project(self.project_id);
        project.song.patterns.push(pattern);

        vec![Reply::PatternAdded]
    }

    fn rollback(&self, store: &mut Store) -> Vec<Reply> {
        store
            .get_project(self.project_id)
            .song
            .patterns
            .retain(|pattern| pattern.id != self.pattern_id);

        vec![Reply::PatternDeleted]
    }
}
