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

use serde::{Deserialize, Serialize};

use crate::model::pattern::Pattern;
use crate::util::id::get_id;

#[rid::model]
#[rid::structs(Pattern)]
#[derive(Serialize, Deserialize)]
pub struct Song {
    pub id: u64,
    pub ticks_per_quarter: u64,
    pub patterns: Vec<Pattern>,

    // TODO: replace with Option<u64> when RID implements that
    // until then, 0 means none selected
    pub active_pattern_id: u64,
    pub active_instrument_id: u64,
    pub active_controller_id: u64,
}

impl Default for Song {
    fn default() -> Self {
        Song {
            id: get_id(),
            ticks_per_quarter: 96,
            patterns: Vec::new(),
            active_pattern_id: 0,
            active_instrument_id: 0,
            active_controller_id: 0,
        }
    }
}
