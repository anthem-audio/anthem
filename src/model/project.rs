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

use crate::model::generator::{Controller, Instrument};
use crate::model::song::Song;
use crate::util::id::get_id;

fn default_file_path() -> String {
    "".to_string()
}

fn default_is_saved() -> bool {
    true
}

#[rid::model]
#[rid::structs(Song, Instrument, Controller)]
#[derive(Serialize, Deserialize, rid::Config)]
pub struct Project {
    pub id: u64,

    // TODO: replace with Option<String> when rid gets option support
    #[serde(skip_serializing, default = "default_is_saved")]
    pub is_saved: bool,
    #[serde(skip_serializing, default = "default_file_path")]
    pub file_path: String,

    pub song: Song,

    pub instruments: HashMap<u64, Instrument>,
    pub controllers: HashMap<u64, Controller>,
    pub generator_list: Vec<u64>,
}

impl Default for Project {
    fn default() -> Self {
        Project {
            id: get_id(),
            is_saved: false,
            file_path: "".into(),
            song: Song::default(),
            instruments: HashMap::new(),
            controllers: HashMap::new(),
            generator_list: Vec::new(),
        }
    }
}
