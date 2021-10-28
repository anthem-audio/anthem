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

#[rid::model]
#[derive(Clone, Serialize, Deserialize)]
pub struct TimeSignature {
    pub numerator: u64,
    pub denominator: u64,
}

#[rid::model]
#[rid::structs(TimeSignature)]
#[derive(Clone, Serialize, Deserialize)]
pub struct TimeSignatureChange {
    pub offset: u64,
    pub time_signature: TimeSignature,
}
