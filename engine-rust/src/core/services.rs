// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::any::{Any, TypeId, type_name};
use std::cell::RefCell;
use std::collections::HashMap;
use std::marker::PhantomData;
use std::rc::Rc;

thread_local! {
    static SERVICES: RefCell<Option<ServiceRegistry>> = const { RefCell::new(None) };
}

#[derive(Default)]
pub struct ServiceRegistry {
    instances: HashMap<TypeId, Rc<dyn Any>>,
}

impl ServiceRegistry {
    pub fn register<T: 'static>(&mut self, service: T) {
        let id = TypeId::of::<T>();
        assert!(
            !self.instances.contains_key(&id),
            "Service {} was already registered",
            type_name::<T>()
        );
        self.instances.insert(id, Rc::new(service));
    }

    /// Installs these services until the returned guard is dropped.
    pub fn install(self) -> ServiceScope {
        SERVICES.with_borrow_mut(|slot| {
            assert!(
                slot.is_none(),
                "Message-thread services are already installed"
            );
            *slot = Some(self);
        });
        ServiceScope {
            _message_thread: PhantomData,
        }
    }
}

#[must_use = "Keep this guard alive while using message-thread services"]
pub struct ServiceScope {
    // The guard must be dropped on the thread where services were installed.
    _message_thread: PhantomData<Rc<()>>,
}

impl Drop for ServiceScope {
    fn drop(&mut self) {
        let registry = SERVICES.with_borrow_mut(Option::take);
        drop(registry);
    }
}

pub fn with<T: 'static, R>(access: impl FnOnce(&T) -> R) -> R {
    access(&get::<T>())
}

/// Returns an owned service handle for work that must outlive a scoped lookup.
/// A task can retain this handle across awaits without borrowing the registry.
pub fn get<T: 'static>() -> Rc<T> {
    let service = SERVICES.with_borrow(|slot| {
        let registry = slot
            .as_ref()
            .expect("Message-thread services are unavailable on this thread");
        registry
            .instances
            .get(&TypeId::of::<T>())
            .unwrap_or_else(|| panic!("Service {} is not registered", type_name::<T>()))
            .clone()
    });

    // Release the registry borrow before the caller uses the service.
    service.downcast::<T>().unwrap_or_else(|_| unreachable!())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{panic, thread};

    #[test]
    fn callbacks_can_look_up_another_service() {
        let mut registry = ServiceRegistry::default();
        registry.register(42u32);
        registry.register(Rc::new("project"));

        let _services = registry.install();
        let result = with::<u32, _>(|number| with::<Rc<&str>, _>(|name| (**name, *number)));
        assert_eq!(result, ("project", 42));
    }

    #[test]
    fn services_are_available_only_on_the_installing_thread_during_the_scope() {
        let mut registry = ServiceRegistry::default();
        registry.register(42u32);

        let services = registry.install();
        assert_eq!(with::<u32, _>(|value| *value), 42);
        thread::spawn(|| {
            assert!(panic::catch_unwind(|| with::<u32, _>(|_| ())).is_err());
        })
        .join()
        .unwrap();
        drop(services);

        assert!(panic::catch_unwind(|| with::<u32, _>(|_| ())).is_err());
        let mut next_session = ServiceRegistry::default();
        next_session.register(7u32);
        let _services = next_session.install();
        assert_eq!(with::<u32, _>(|value| *value), 7);
    }
}
