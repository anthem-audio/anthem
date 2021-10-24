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

fn add_pattern(store: &mut Store, project_id: u64, pattern: &Pattern) {
    let pattern = pattern.clone();
    let project = store.get_project(project_id);
    project.song.patterns.push(pattern);
}

fn delete_pattern(store: &mut Store, project_id: u64, pattern_id: u64) {
    store
        .get_project(project_id)
        .song
        .patterns
        .retain(|pattern| pattern.id != pattern_id);
}

pub struct AddPatternCommand {
    pub project_id: u64,
    pub pattern: Pattern,
}

impl Command for AddPatternCommand {
    fn execute(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        add_pattern(store, self.project_id, &self.pattern);
        vec![Reply::PatternAdded(request_id)]
    }

    fn rollback(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        delete_pattern(store, self.project_id, self.pattern.id);
        vec![Reply::PatternDeleted(request_id)]
    }
}

pub struct DeletePatternCommand {
    pub project_id: u64,
    pub pattern: Pattern,
}

impl Command for DeletePatternCommand {
    fn execute(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        delete_pattern(store, self.project_id, self.pattern.id);
        vec![Reply::PatternDeleted(request_id)]
    }
    
    fn rollback(&self, store: &mut Store, request_id: u64) -> Vec<Reply> {
        add_pattern(store, self.project_id, &self.pattern);
        vec![Reply::PatternAdded(request_id)]
    }
}
