/*
    Copyright (C) 2022 Joshua Wade

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

use crate::engine_bridge::EngineBridge;

use lazy_static::lazy_static;
use std::sync::Mutex;
use std::collections::HashMap;

pub struct State {
    pub engine_processes: HashMap<i64, EngineBridge>
}

impl State {
    pub fn new() -> Self {
        State {
            engine_processes: HashMap::new()
        }
    }
}

lazy_static! {
    pub static ref STATE: Mutex<State> = Mutex::new(State::new());
}
