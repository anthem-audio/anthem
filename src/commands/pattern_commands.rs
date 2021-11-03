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

fn add_pattern(project: &mut Project, pattern: &Pattern, index: usize) {
    let pattern = pattern.clone();
    project.song.pattern_order.insert(index, pattern.id);
    project.song.patterns.insert(pattern.id, pattern);
}

fn delete_pattern(project: &mut Project, pattern_id: u64) {
    project.song.pattern_order.retain(|id| *id != pattern_id);
    project.song.patterns.remove(&pattern_id);
}

pub struct AddPatternCommand {
    pub project_id: u64,
    pub pattern: Pattern,
    pub index: usize,
}

impl Command for AddPatternCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_pattern(project, &self.pattern, self.index);
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
    pub index: usize,
}

impl Command for DeletePatternCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        delete_pattern(project, self.pattern.id);
        vec![Reply::PatternDeleted(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_pattern(project, &self.pattern, self.index);
        vec![Reply::PatternAdded(request_id)]
    }
}

pub struct AddNoteCommand {
    pub project_id: u64,
    pub pattern_id: u64,
    pub generator_id: u64,
    pub note: Note,
}

fn add_note(project: &mut Project, pattern_id: u64, generator_id: u64, note: &Note) {
    let pattern = project.song.patterns.get_mut(&pattern_id).unwrap();
    if pattern.generator_notes.get(&generator_id).is_none() {
        pattern
            .generator_notes
            .insert(generator_id, GeneratorNotes::default());
    }
    let note_list = &mut pattern
        .generator_notes
        .get_mut(&generator_id)
        .unwrap()
        .notes;
    note_list.push(note.clone());
    // sort?
}

fn remove_note(project: &mut Project, pattern_id: u64, generator_id: u64, note_id: u64) {
    let pattern = project.song.patterns.get_mut(&pattern_id).unwrap();
    let note_list = &mut pattern
        .generator_notes
        .get_mut(&generator_id)
        .unwrap()
        .notes;
    note_list.retain(|note| note.id != note_id);
}

fn move_note(
    project: &mut Project,
    pattern_id: u64,
    generator_id: u64,
    note_id: u64,
    new_offset: u64,
) {
    let pattern = project.song.patterns.get_mut(&pattern_id).unwrap();
    let note_list = &mut pattern
        .generator_notes
        .get_mut(&generator_id)
        .unwrap()
        .notes;
    let note = note_list
        .iter_mut()
        .find(|note| note.id == note_id)
        .unwrap();
    note.offset = new_offset;
}

fn resize_note(
    project: &mut Project,
    pattern_id: u64,
    generator_id: u64,
    note_id: u64,
    new_length: u64,
) {
    let pattern = project.song.patterns.get_mut(&pattern_id).unwrap();
    let note_list = &mut pattern
        .generator_notes
        .get_mut(&generator_id)
        .unwrap()
        .notes;
    let note = note_list
        .iter_mut()
        .find(|note| note.id == note_id)
        .unwrap();
    note.length = new_length;
}

fn get_note_reply(pattern_id: u64, generator_id: u64) -> String {
    format!(
        r#"{{ "patternID":{},"generatorID":{} }}"#,
        pattern_id as i64, generator_id as i64
    )
}

impl Command for AddNoteCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_note(project, self.pattern_id, self.generator_id, &self.note);
        vec![Reply::NoteAdded(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        remove_note(project, self.pattern_id, self.generator_id, self.note.id);
        vec![Reply::NoteDeleted(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }
}

pub struct DeleteNoteCommand {
    pub project_id: u64,
    pub pattern_id: u64,
    pub generator_id: u64,
    pub note: Note,
}

impl Command for DeleteNoteCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        remove_note(project, self.pattern_id, self.generator_id, self.note.id);
        vec![Reply::NoteDeleted(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        add_note(project, self.pattern_id, self.generator_id, &self.note);
        vec![Reply::NoteAdded(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }
}

pub struct MoveNoteCommand {
    pub project_id: u64,
    pub pattern_id: u64,
    pub generator_id: u64,
    pub note_id: u64,
    pub old_key: u8,
    pub new_key: u8,
    pub old_offset: u64,
    pub new_offset: u64,
}

impl Command for MoveNoteCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        move_note(
            project,
            self.pattern_id,
            self.generator_id,
            self.note_id,
            self.new_offset,
        );
        vec![Reply::NoteMoved(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        move_note(
            project,
            self.pattern_id,
            self.generator_id,
            self.note_id,
            self.old_offset,
        );
        vec![Reply::NoteMoved(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }
}

pub struct ResizeNoteCommand {
    pub project_id: u64,
    pub pattern_id: u64,
    pub generator_id: u64,
    pub note_id: u64,
    pub old_length: u64,
    pub new_length: u64,
}

impl Command for ResizeNoteCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        resize_note(
            project,
            self.pattern_id,
            self.generator_id,
            self.note_id,
            self.new_length,
        );
        vec![Reply::NoteMoved(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        resize_note(
            project,
            self.pattern_id,
            self.generator_id,
            self.note_id,
            self.old_length,
        );
        vec![Reply::NoteMoved(
            request_id,
            get_note_reply(self.pattern_id, self.generator_id),
        )]
    }
}
