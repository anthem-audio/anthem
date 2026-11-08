// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::any::Any;
use std::fmt;

use serde::de::DeserializeOwned;

use crate::messages::{FieldAccess, FieldType, FieldUpdateKind};

#[derive(Clone, Debug)]
pub struct SyncError(String);

impl SyncError {
    pub fn new(reason: impl Into<String>) -> Self {
        Self(reason.into())
    }

    pub fn at(self, location: impl fmt::Display) -> Self {
        Self(format!("{location}: {}", self.0))
    }
}

impl fmt::Display for SyncError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

impl std::error::Error for SyncError {}

impl From<serde_json::Error> for SyncError {
    fn from(error: serde_json::Error) -> Self {
        Self(error.to_string())
    }
}

/// The remaining path and operation while forwarding an update through the tree.
#[derive(Clone, Copy)]
pub struct ModelUpdate<'a> {
    pub path: &'a [FieldAccess],
    pub kind: FieldUpdateKind,
    pub json: Option<&'a str>,
}

impl<'a> ModelUpdate<'a> {
    pub fn field(self) -> Result<&'a str, SyncError> {
        let access = self.access(FieldType::Raw)?;
        access
            .field_name
            .as_deref()
            .ok_or_else(|| SyncError::new("Field name is missing"))
    }

    pub fn access(self, expected: FieldType) -> Result<&'a FieldAccess, SyncError> {
        let access = self
            .path
            .first()
            .ok_or_else(|| SyncError::new("Update path is empty"))?;
        if access.field_type != expected {
            return Err(SyncError::new(format!("Expected a {expected:?} accessor")));
        }
        Ok(access)
    }

    pub fn next(self) -> Self {
        Self {
            path: &self.path[1..],
            ..self
        }
    }

    pub fn decode<T: DeserializeOwned>(self) -> Result<T, SyncError> {
        let json = self
            .json
            .ok_or_else(|| SyncError::new("Update value is missing"))?;
        Ok(serde_json::from_str(json)?)
    }

    pub fn replacement<T: DeserializeOwned>(self) -> Result<T, SyncError> {
        if !self.path.is_empty() || self.kind != FieldUpdateKind::Set {
            return Err(SyncError::new("This value only supports replacement"));
        }
        self.decode()
    }
}

/// Holds a removed subtree until the outermost model borrow has been released.
/// A single update replaces or removes at most one subtree.
#[derive(Default)]
#[must_use = "Finish the change after releasing model borrows"]
pub struct ModelChange(Option<Box<dyn Any>>);

impl ModelChange {
    pub fn removed<T: 'static>(value: T) -> Self {
        Self(Some(Box::new(value)))
    }

    pub fn finish(self) {
        // Removal happens after mutation has returned, so dropping an old model
        // cannot run its cleanup while one of its ancestors is mutably borrowed.
        drop(self.0);
        // Initialization hooks and field observers will run after removal when
        // behavior support is added. They must stay inside this update boundary,
        // before the message thread handles the next request.
    }
}

pub type SyncResult = Result<ModelChange, SyncError>;

/// Common update handling for model fields, collections, and their elements.
pub trait ModelValue: DeserializeOwned + 'static {
    fn apply_update(&mut self, update: ModelUpdate<'_>) -> SyncResult {
        replace(self, update)
    }
}

pub fn replace<T: DeserializeOwned + 'static>(
    value: &mut T,
    update: ModelUpdate<'_>,
) -> SyncResult {
    // Decode the replacement before assigning it. A malformed value is a fatal
    // sync error, and must not create a half-deserialized model.
    let replacement = update.replacement()?;
    let old = std::mem::replace(value, replacement);
    Ok(ModelChange::removed(old))
}

macro_rules! primitive_values {
    ($($type:ty),* $(,)?) => { $(
        impl ModelValue for $type {
            fn apply_update(&mut self, update: ModelUpdate<'_>) -> SyncResult {
                // Primitive values have no model lifecycle work to defer.
                *self = update.replacement()?;
                Ok(ModelChange::default())
            }
        }
    )* };
}

primitive_values!(i64, f64, bool, String, serde_json::Number, super::Color);

impl<T: ModelValue> ModelValue for Option<T> {
    fn apply_update(&mut self, update: ModelUpdate<'_>) -> SyncResult {
        if update.path.is_empty() {
            return replace(self, update);
        }
        self.as_mut()
            .ok_or_else(|| SyncError::new("Cannot forward an update through null"))?
            .apply_update(update)
    }
}

impl<T: ModelValue> ModelValue for super::ModelRef<T> {
    fn apply_update(&mut self, update: ModelUpdate<'_>) -> SyncResult {
        if update.path.is_empty() {
            return replace(self, update);
        }
        self.0
            .try_borrow_mut()
            .map_err(|_| SyncError::new("Model is already borrowed during an update"))?
            .apply_update(update)
    }
}
