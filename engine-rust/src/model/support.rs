// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::cell::RefCell;
use std::rc::Rc;

/// A shared model instance. Reads borrow it only for the duration of the callback.
#[derive(Debug, serde::Serialize, serde::Deserialize)]
#[serde(transparent)]
pub struct ModelRef<T>(Rc<RefCell<T>>);

impl<T> ModelRef<T> {
    pub fn with<R>(&self, read: impl FnOnce(&T) -> R) -> R {
        read(&self.0.borrow())
    }
}

impl<T> Clone for ModelRef<T> {
    fn clone(&self) -> Self {
        Self(Rc::clone(&self.0))
    }
}

/// Dart's serialized Color channels, expressed as bytes in the existing JSON.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Color {
    pub a: u8,
    pub r: u8,
    pub g: u8,
    pub b: u8,
}
