// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::HashMap;
use std::hash::Hash;
use std::ops::Deref;

use serde::{Deserialize, Serialize, de::DeserializeOwned};

use super::sync::{ModelChange, ModelUpdate, ModelValue, SyncError, SyncResult, replace};
use crate::messages::{FieldType, FieldUpdateKind};

/// A model list owns its data and forwards nested updates to its elements.
#[derive(Debug, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ModelList<T> {
    data: Vec<T>,
}

impl<T> Deref for ModelList<T> {
    type Target = [T];

    fn deref(&self) -> &[T] {
        &self.data
    }
}

impl<T: ModelValue> ModelValue for ModelList<T> {
    fn apply_update(&mut self, update: ModelUpdate<'_>) -> SyncResult {
        if update.path.is_empty() {
            return replace(self, update);
        }
        let access = update.access(FieldType::List)?;
        let index = access
            .list_index
            .and_then(|index| usize::try_from(index).ok())
            .ok_or_else(|| SyncError::new("List index is missing or negative"))?;
        let tail = update.next();

        // Structural operations belong to this list. If the path goes deeper,
        // the element handles the update, even when it is another collection.
        let result = if tail.path.is_empty() && update.kind == FieldUpdateKind::Add {
            if index > self.data.len() {
                return Err(SyncError::new("List insertion index is out of bounds").at(index));
            }
            let value = update.decode()?;
            self.data.insert(index, value);
            Ok(ModelChange::default())
        } else {
            if index >= self.data.len() {
                return Err(SyncError::new("List index is out of bounds").at(index));
            }
            if tail.path.is_empty() && update.kind == FieldUpdateKind::Remove {
                Ok(ModelChange::removed(self.data.remove(index)))
            } else {
                self.data[index].apply_update(tail)
            }
        };
        result.map_err(|error| error.at(format_args!("[{index}]")))
    }
}

/// A model map owns its data and forwards nested updates to its values.
#[derive(Debug, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ModelMap<K: Eq + Hash, V> {
    data: HashMap<K, V>,
}

impl<K: Eq + Hash, V> Deref for ModelMap<K, V> {
    type Target = HashMap<K, V>;

    fn deref(&self) -> &Self::Target {
        &self.data
    }
}

impl<K: Eq + Hash + DeserializeOwned + 'static, V: ModelValue> ModelValue for ModelMap<K, V> {
    fn apply_update(&mut self, update: ModelUpdate<'_>) -> SyncResult {
        if update.path.is_empty() {
            return replace(self, update);
        }
        let access = update.access(FieldType::Map)?;
        let json = access
            .serialized_map_key
            .as_deref()
            .ok_or_else(|| SyncError::new("Map key is missing"))?;
        let key: K = serde_json::from_str(json)?;
        let tail = update.next();

        // Setting a map entry inserts or replaces it. Forwarding a deeper update
        // requires an existing entry; it must not silently create a new model.
        let result = if tail.path.is_empty() {
            match update.kind {
                FieldUpdateKind::Set => {
                    let value = update.decode()?;
                    Ok(self
                        .data
                        .insert(key, value)
                        .map_or_else(ModelChange::default, ModelChange::removed))
                }
                FieldUpdateKind::Remove => Ok(self
                    .data
                    .remove(&key)
                    .map_or_else(ModelChange::default, ModelChange::removed)),
                FieldUpdateKind::Add => Err(SyncError::new("Map entries use set, not add")),
            }
        } else {
            self.data
                .get_mut(&key)
                .ok_or_else(|| SyncError::new("Map entry does not exist"))?
                .apply_update(tail)
        };
        result.map_err(|error| error.at(format_args!("[{json}]")))
    }
}
