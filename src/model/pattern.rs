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

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::model::note::*;
use crate::model::time_signature::{TimeSignature, TimeSignatureChange};
use crate::util::id::get_id;

#[rid::model]
#[rid::structs(GeneratorNotes, TimeSignature, TimeSignatureChange)]
#[derive(Clone, Serialize, Deserialize)]
pub struct Pattern {
    pub id: u64,
    pub name: String,
    pub generator_notes: HashMap<u64, GeneratorNotes>,
    pub time_signature_changes: Vec<TimeSignatureChange>,
    pub default_time_signature: TimeSignature,
}

#[rid::model]
#[rid::structs(Note)]
#[derive(Clone, Serialize, Deserialize)]
pub struct GeneratorNotes {
    pub notes: Vec<Note>,
}

impl Default for GeneratorNotes {
    fn default() -> Self {
        GeneratorNotes { notes: Vec::new() }
    }
}

impl Pattern {
    pub fn new(name: String) -> Self {
        Pattern {
            id: get_id(),
            name,
            generator_notes: HashMap::new(),
            default_time_signature: TimeSignature {
                numerator: 4,
                denominator: 4,
            },
            time_signature_changes: Vec::new(),
        }
    }
}
