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

use rid::RidStore;

#[rid::store]
#[derive(Debug)]
pub struct Store {
    count: u32,
}

impl RidStore<Msg> for Store {
    fn create() -> Self {
        Self { count: 0 }
    }

    fn update(&mut self, req_id: u64, msg: Msg) {
        match msg {
            Msg::Inc => {
                self.count += 1;
                rid::post(Reply::Increased(req_id));
            }
            Msg::Add(n) => {
                self.count += n;
                rid::post(Reply::Added(req_id, n.to_string()));
            }
        }
    }
}

#[rid::message(Reply)]
#[derive(Debug)]
pub enum Msg {
    Inc,
    Add(u32),
}

#[rid::reply]
pub enum Reply {
    Increased(u64),
    Added(u64, String),
}
