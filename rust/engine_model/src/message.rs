/*
    Copyright (C) 2021 - 2022 Joshua Wade

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

use super::project::Project;

#[derive(Serialize, Deserialize)]
pub enum Request {
    // Lifecycle
    Init,
    Exit,

    // Save / Load
    GetModel,
    LoadModel(Project),
}

#[derive(Serialize, Deserialize)]
pub struct RequestWrapper {
    pub id: u64,
    pub request: Request,
}

impl RequestWrapper {
    pub fn new(id: u64, request: Request) -> Self {
        RequestWrapper { id, request }
    }
}

#[derive(Serialize, Deserialize)]
pub enum Reply {
    // Lifecycle

    // Save / Load
    GetModelReply(Project),
}

#[derive(Serialize, Deserialize)]
pub struct ReplyWrapper {
    pub id: u64,
    pub reply: Option<Reply>,
}

impl ReplyWrapper {
    pub fn new(id: u64, reply: Option<Reply>) -> Self {
        ReplyWrapper { id, reply }
    }
}
