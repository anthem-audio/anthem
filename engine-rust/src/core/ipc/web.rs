// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use super::{Outgoing, message_length};
use crate::core::{Application, runtime, services};
use std::sync::{
    OnceLock,
    atomic::{AtomicBool, AtomicU8, AtomicU32, Ordering},
};
use std::time::Duration;
use tokio::sync::mpsc::UnboundedReceiver;

const CAPACITY: u32 = 65536;
static RINGS: OnceLock<Rings> = OnceLock::new();
static EXITED: AtomicBool = AtomicBool::new(false);
static EXIT_CODE: AtomicU32 = AtomicU32::new(0);
static SHUTDOWN_REQUESTED: AtomicBool = AtomicBool::new(false);

struct Ring {
    head: AtomicU32,
    tail: AtomicU32,
    ticket: AtomicU32,
    data: Box<[AtomicU8]>,
}

impl Ring {
    fn new() -> Self {
        Self {
            head: AtomicU32::new(0),
            tail: AtomicU32::new(0),
            ticket: AtomicU32::new(0),
            data: (0..CAPACITY).map(|_| AtomicU8::new(0)).collect(),
        }
    }
    fn push(&self, value: u8) -> bool {
        let head = self.head.load(Ordering::Relaxed);
        let next = (head + 1) & (CAPACITY - 1);
        if next == self.tail.load(Ordering::Acquire) {
            return false;
        }
        self.data[head as usize].store(value, Ordering::Relaxed);
        self.head.store(next, Ordering::Release);
        true
    }
    fn pop(&self) -> Option<u8> {
        let tail = self.tail.load(Ordering::Relaxed);
        if tail == self.head.load(Ordering::Acquire) {
            return None;
        }
        let value = self.data[tail as usize].load(Ordering::Relaxed);
        self.tail
            .store((tail + 1) & (CAPACITY - 1), Ordering::Release);
        Some(value)
    }
    fn read_exact(&self, output: &mut [u8], stopped: &AtomicBool) -> std::io::Result<()> {
        for byte in output {
            loop {
                let ticket = self.ticket.load(Ordering::Acquire);
                if stopped.load(Ordering::Acquire) {
                    return Err(std::io::ErrorKind::Interrupted.into());
                }
                // Read the ticket before checking the queue to avoid losing a
                // notification between observing an empty queue and sleeping.
                if let Some(value) = self.pop() {
                    *byte = value;
                    break;
                }
                unsafe {
                    emscripten_futex_wait(self.ticket.as_ptr().cast(), ticket, f64::INFINITY);
                }
            }
        }
        Ok(())
    }
}

struct Rings {
    to_ui: Ring,
    from_ui: Ring,
    stopped: AtomicBool,
}

unsafe extern "C" {
    fn emscripten_futex_wait(address: *const u32, expected: u32, timeout: f64) -> i32;
    fn emscripten_futex_wake(address: *const u32, count: i32) -> i32;
}

struct Reader(Option<std::thread::JoinHandle<()>>);
impl Drop for Reader {
    fn drop(&mut self) {
        let rings = RINGS.get().unwrap();
        rings.stopped.store(true, Ordering::Release);
        rings.from_ui.ticket.fetch_add(1, Ordering::Release);
        unsafe {
            emscripten_futex_wake(rings.from_ui.ticket.as_ptr().cast(), 1);
        }
        // Join before freeing transport state or message-thread services.
        if let Some(thread) = self.0.take() {
            let _ = thread.join();
        }
    }
}

pub(super) async fn run(mut outgoing: UnboundedReceiver<Outgoing>) -> std::io::Result<()> {
    let rings = RINGS.get_or_init(|| Rings {
        to_ui: Ring::new(),
        from_ui: Ring::new(),
        stopped: AtomicBool::new(false),
    });
    let _reader = Reader(Some(std::thread::spawn(move || {
        let result = (|| -> std::io::Result<()> {
            loop {
                let mut header = [0; 8];
                rings.from_ui.read_exact(&mut header, &rings.stopped)?;
                let mut body = vec![0; message_length(header)?];
                rings.from_ui.read_exact(&mut body, &rings.stopped)?;
                if runtime::post(move || super::receive(&body)).is_err() {
                    return Ok(());
                }
            }
        })();
        if !rings.stopped.load(Ordering::Acquire) {
            if let Err(error) = result {
                let _ = runtime::post(move || {
                    services::with::<Application, _>(|app| {
                        app.report_fatal_error(error);
                    })
                });
            }
        }
    })));
    let mut introduction = Vec::from(8u64.to_ne_bytes());
    introduction.extend_from_slice(&0i64.to_ne_bytes());
    write(&introduction).await;
    while let Some(message) = outgoing.recv().await {
        write(&message.bytes).await;
        if let Some(flushed) = message.flushed {
            let _ = flushed.send(());
        }
    }
    Ok(())
}

async fn write(bytes: &[u8]) {
    let ring = &RINGS.get().unwrap().to_ui;
    for &byte in bytes {
        while !ring.push(byte) {
            // The browser drains the output on frames; never block the message
            // thread while waiting for it to make space.
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    }
    ring.ticket.fetch_add(1, Ordering::Release);
    unsafe {
        emscripten_futex_wake(ring.ticket.as_ptr().cast(), 1);
    }
}

pub(crate) fn finished(failed: bool) {
    EXIT_CODE.store(u32::from(failed), Ordering::Release);
    EXITED.store(true, Ordering::Release);
}

pub(crate) fn shutdown_requested() -> bool {
    SHUTDOWN_REQUESTED.load(Ordering::Acquire)
}

#[unsafe(no_mangle)]
pub extern "C" fn isCommsReady() -> u32 {
    u32::from(RINGS.get().is_some())
}
#[unsafe(no_mangle)]
pub extern "C" fn hasEngineExited() -> u32 {
    u32::from(EXITED.load(Ordering::Acquire))
}
#[unsafe(no_mangle)]
pub extern "C" fn getEngineExitCode() -> u32 {
    EXIT_CODE.load(Ordering::Acquire)
}
#[unsafe(no_mangle)]
pub extern "C" fn requestEngineShutdown() {
    // The browser may cancel before Rust main has installed its message queue.
    // Startup checks this flag after installation, so that request is not lost.
    SHUTDOWN_REQUESTED.store(true, Ordering::Release);
    let _ = runtime::post(|| services::with::<Application, _>(Application::shutdown));
}

macro_rules! exports {
    ($ring:ident, $head:ident, $tail:ident, $capacity:ident, $mask:ident, $data:ident, $ticket:ident) => {
        #[unsafe(no_mangle)]
        pub extern "C" fn $head() -> *mut u32 {
            RINGS.get().unwrap().$ring.head.as_ptr()
        }
        #[unsafe(no_mangle)]
        pub extern "C" fn $tail() -> *mut u32 {
            RINGS.get().unwrap().$ring.tail.as_ptr()
        }
        #[unsafe(no_mangle)]
        pub extern "C" fn $capacity() -> u32 {
            CAPACITY
        }
        #[unsafe(no_mangle)]
        pub extern "C" fn $mask() -> u32 {
            CAPACITY - 1
        }
        #[unsafe(no_mangle)]
        pub extern "C" fn $data() -> *const AtomicU8 {
            RINGS.get().unwrap().$ring.data.as_ptr()
        }
        #[unsafe(no_mangle)]
        pub extern "C" fn $ticket() -> *mut u32 {
            RINGS.get().unwrap().$ring.ticket.as_ptr()
        }
    };
}

// Names are from the UI's perspective: its read buffer is our output buffer.
exports!(
    to_ui,
    getReadBufferHeadPtr,
    getReadBufferTailPtr,
    getReadBufferCapacity,
    getReadBufferMask,
    getReadBufferDataPtr,
    getReadBufferTicketPtr
);
exports!(
    from_ui,
    getWriteBufferHeadPtr,
    getWriteBufferTailPtr,
    getWriteBufferCapacity,
    getWriteBufferMask,
    getWriteBufferDataPtr,
    getWriteBufferTicketPtr
);
