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
use crate::model::{note::*, pattern::*, project::*, store::Reply};

fn add_pattern(project: &mut Project, pattern: &Pattern) {
    let pattern = pattern.clone();
    project.song.patterns.push(pattern);
}

fn delete_pattern(project: &mut Project, pattern_id: u64) {
    project
        .song
        .patterns
        .retain(|pattern| pattern.id != pattern_id);
}

pub struct AddPatternCommand {
    pub project_id: u64,
    pub pattern: Pattern,
}

impl Command for AddPatternCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_pattern(project, &self.pattern);
        vec![Reply::PatternAdded(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        delete_pattern(project, self.pattern.id);
        vec![Reply::PatternDeleted(request_id)]
    }
}

pub struct DeletePatternCommand {
    pub project_id: u64,
    pub pattern: Pattern,
}

impl Command for DeletePatternCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        delete_pattern(project, self.pattern.id);
        vec![Reply::PatternDeleted(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_pattern(project, &self.pattern);
        vec![Reply::PatternAdded(request_id)]
    }
}

pub struct AddNoteCommand {
    pub project_id: u64,
    pub pattern_id: u64,
    pub channel_id: u64,
    pub note: Note,
}

fn add_note(project: &mut Project, pattern_id: u64, channel_id: u64, note: &Note) {
    let pattern = project
        .song
        .patterns
        .iter_mut()
        .find(|pattern| pattern.id == pattern_id)
        .unwrap();
    if pattern.channel_notes.get(&channel_id).is_none() {
        pattern
            .channel_notes
            .insert(channel_id, ChannelNotes::default());
    }
    let note_list = &mut pattern.channel_notes.get_mut(&channel_id).unwrap().notes;
    note_list.push(note.clone());
    // sort?
}

fn remove_note(project: &mut Project, pattern_id: u64, channel_id: u64, note_id: u64) {
    let pattern = project
        .song
        .patterns
        .iter_mut()
        .find(|pattern| pattern.id == pattern_id)
        .unwrap();
    let note_list = &mut pattern.channel_notes.get_mut(&channel_id).unwrap().notes;
    note_list.retain(|note| note.id != note_id);
}

impl Command for AddNoteCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_note(project, self.pattern_id, self.channel_id, &self.note);
        vec![Reply::NoteAdded(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        remove_note(project, self.pattern_id, self.channel_id, self.note.id);
        vec![Reply::NoteDeleted(request_id)]
    }
}

pub struct DeleteNoteCommand {
    pub project_id: u64,
    pub pattern_id: u64,
    pub channel_id: u64,
    pub note: Note,
}

impl Command for DeleteNoteCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        remove_note(project, self.pattern_id, self.channel_id, self.note.id);
        vec![Reply::NoteDeleted(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_note(project, self.pattern_id, self.channel_id, &self.note);
        vec![Reply::NoteAdded(request_id)]
    }
}
