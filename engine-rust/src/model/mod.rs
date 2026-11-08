// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

mod collections;
mod support;
pub mod sync;

pub use collections::{ModelList, ModelMap};
pub use support::{Color, ModelRef};

#[path = "../generated/lib/model/model.rs"]
mod generated;

pub use generated::*;
