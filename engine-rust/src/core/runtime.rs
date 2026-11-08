// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::BTreeMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::time::Instant;

type Job = Box<dyn FnOnce() + Send + 'static>;

static MESSAGE_THREAD: Mutex<Option<MessageThreadHandle>> = Mutex::new(None);

/// Posts work to the installed message thread from any thread.
/// This path can allocate and lock, so use it for control and worker threads.
pub fn post(job: impl FnOnce() + Send + 'static) -> Result<(), MessageThreadClosed> {
    let handle = MESSAGE_THREAD
        .lock()
        .unwrap()
        .clone()
        .ok_or(MessageThreadClosed)?;
    handle.post(job)
}

enum Event {
    Job(Job),
    Wake,
    Shutdown,
}

enum ScheduleUpdate {
    Add(ScheduledJobId, Job),
    Cancel(ScheduledJobId),
}

/// An ID for a scheduled job.
///
/// The `Instant` is a future time that this work should be handled, if created
/// using post_at(). Lower times are prioritized.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct ScheduledJobId(Instant, u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MessageThreadClosed;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MessageThreadAlreadyInstalled;

#[must_use = "Keep this guard alive while posting to the global message thread"]
pub struct MessageThreadScope(());

impl Drop for MessageThreadScope {
    fn drop(&mut self) {
        let handle = MESSAGE_THREAD.lock().unwrap().take();
        drop(handle);
    }
}

#[derive(Clone)]
pub struct MessageThreadHandle {
    inbox: Sender<Event>,
    schedule: Sender<ScheduleUpdate>,
    next_job_id: Arc<AtomicU64>,
}

impl MessageThreadHandle {
    /// Makes this queue available through `runtime::post` until the guard is dropped.
    pub fn install(&self) -> Result<MessageThreadScope, MessageThreadAlreadyInstalled> {
        let mut installed = MESSAGE_THREAD.lock().unwrap();
        if installed.is_some() {
            return Err(MessageThreadAlreadyInstalled);
        }
        *installed = Some(self.clone());
        Ok(MessageThreadScope(()))
    }

    pub fn post(&self, job: impl FnOnce() + Send + 'static) -> Result<(), MessageThreadClosed> {
        self.inbox
            .send(Event::Job(Box::new(job)))
            .map_err(|_| MessageThreadClosed)
    }

    pub fn post_at(
        &self,
        deadline: Instant,
        job: impl FnOnce() + Send + 'static,
    ) -> Result<ScheduledJobId, MessageThreadClosed> {
        let id = ScheduledJobId(deadline, self.next_job_id.fetch_add(1, Ordering::Relaxed));
        self.update_schedule(ScheduleUpdate::Add(id, Box::new(job)))?;
        Ok(id)
    }

    pub fn cancel_scheduled(&self, id: ScheduledJobId) {
        let _ = self.update_schedule(ScheduleUpdate::Cancel(id));
    }

    fn update_schedule(&self, update: ScheduleUpdate) -> Result<(), MessageThreadClosed> {
        self.schedule
            .send(update)
            .map_err(|_| MessageThreadClosed)?;
        self.inbox
            .send(Event::Wake)
            .map_err(|_| MessageThreadClosed)
    }

    pub fn shutdown(&self) {
        let _ = self.inbox.send(Event::Shutdown);
    }
}

pub struct MessageThread {
    inbox: Receiver<Event>,
    schedule: Receiver<ScheduleUpdate>,
}

impl MessageThread {
    pub fn new() -> (Self, MessageThreadHandle) {
        let (send, inbox) = mpsc::channel();
        let (update_schedule, schedule) = mpsc::channel();
        (
            Self { inbox, schedule },
            MessageThreadHandle {
                inbox: send,
                schedule: update_schedule,
                next_job_id: Arc::new(AtomicU64::new(0)),
            },
        )
    }

    /// Runs jobs on the message thread until shutdown or disconnection.
    pub fn run(self) {
        let mut scheduled = BTreeMap::new();
        loop {
            let mut due_job = None;
            // This loop pulls in all schedule updates. It sets the earliest one
            // to due_job, and puts the rest in the schedule map.
            //
            // The most common case for incoming scheduled work is that it
            // should be run ASAP. Sometimes there will already be prior work in
            // `scheduled` that needs to be run; however, I suspect most of the
            // time the incoming work should be run immediately.
            //
            // By pulling out the earliest incoming work into due_job, we can
            // prevent allocating into the schedule map in this common case.
            for update in self.schedule.try_iter() {
                match update {
                    ScheduleUpdate::Add(id, job) if due_job.is_none() && id.0 <= Instant::now() => {
                        due_job = Some((id, job));
                    }
                    ScheduleUpdate::Add(id, job) => {
                        scheduled.insert(id, job);
                    }
                    ScheduleUpdate::Cancel(id) => {
                        if due_job.as_ref().is_some_and(|(due_id, _)| *due_id == id) {
                            due_job = None;
                        } else {
                            scheduled.remove(&id);
                        }
                    }
                }
            }

            if let Some((id, job)) = due_job {
                if scheduled
                    .first_key_value()
                    .is_none_or(|(&first, _)| id < first)
                {
                    job();
                    continue;
                }
                scheduled.insert(id, job);
            }

            let deadline = scheduled.first_key_value().map(|(id, _)| id.0);
            if deadline.is_some_and(|deadline| deadline <= Instant::now()) {
                let (_, job) = scheduled.pop_first().unwrap();
                job();
                continue;
            }

            let event = match deadline {
                Some(deadline) => self
                    .inbox
                    .recv_timeout(deadline.saturating_duration_since(Instant::now())),
                None => self
                    .inbox
                    .recv()
                    .map_err(|_| RecvTimeoutError::Disconnected),
            };
            match event {
                Ok(Event::Job(job)) => job(),
                Ok(Event::Shutdown) | Err(RecvTimeoutError::Disconnected) => break,
                Ok(Event::Wake) | Err(RecvTimeoutError::Timeout) => {}
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn global_post_routes_worker_jobs_and_cleans_up_between_sessions() {
        assert_eq!(post(|| {}), Err(MessageThreadClosed));

        let (runtime, handle) = MessageThread::new();
        let installation = handle.install().unwrap();
        assert!(matches!(
            handle.install(),
            Err(MessageThreadAlreadyInstalled)
        ));
        let (send, receive) = mpsc::channel();
        let message_thread = thread::current().id();
        thread::spawn(move || {
            post(move || send.send(thread::current().id()).unwrap()).unwrap();
        })
        .join()
        .unwrap();
        handle.shutdown();

        runtime.run();
        assert_eq!(receive.recv().unwrap(), message_thread);
        assert_eq!(post(|| {}), Err(MessageThreadClosed));
        drop(installation);
        assert_eq!(post(|| {}), Err(MessageThreadClosed));

        let (next_runtime, next_handle) = MessageThread::new();
        let _next_installation = next_handle.install().unwrap();
        post(move || next_handle.shutdown()).unwrap();
        next_runtime.run();
    }

    #[test]
    fn runs_posted_jobs_in_order_on_the_message_thread() {
        let (runtime, handle) = MessageThread::new();
        let (send, results) = mpsc::channel();
        let message_thread = thread::current().id();
        let producer = thread::spawn(move || {
            let first = send.clone();
            handle
                .post(move || first.send((1, thread::current().id())).unwrap())
                .unwrap();
            handle
                .post(move || send.send((2, thread::current().id())).unwrap())
                .unwrap();
            handle.shutdown();
        });

        runtime.run();
        producer.join().unwrap();
        assert_eq!(
            results.into_iter().collect::<Vec<_>>(),
            [(1, message_thread), (2, message_thread)]
        );
    }

    #[test]
    fn scheduled_jobs_wake_an_idle_message_thread() {
        let (runtime, handle) = MessageThread::new();
        let message_thread = thread::spawn(move || runtime.run());
        let (send, receive) = mpsc::channel();
        let deadline = Instant::now() + Duration::from_millis(10);
        handle
            .post_at(deadline, move || send.send(Instant::now()).unwrap())
            .unwrap();

        let fired_at = receive.recv_timeout(Duration::from_secs(5));
        handle.shutdown();
        message_thread.join().unwrap();
        assert!(fired_at.unwrap() >= deadline);
    }

    #[test]
    fn due_jobs_run_before_more_queued_jobs() {
        let (runtime, handle) = MessageThread::new();
        let (send, receive) = mpsc::channel();
        let deadline = Instant::now() + Duration::from_millis(10);
        handle
            .post_at(deadline, move || send.send(()).unwrap())
            .unwrap();
        handle
            .post(move || {
                thread::sleep(deadline.saturating_duration_since(Instant::now()));
            })
            .unwrap();
        handle
            .post(move || assert_eq!(receive.try_recv(), Ok(())))
            .unwrap();
        handle.shutdown();

        runtime.run();
    }

    #[test]
    fn cancellation_drops_due_and_future_jobs_before_dispatch() {
        for delay in [Duration::ZERO, Duration::from_secs(60)] {
            let (runtime, handle) = MessageThread::new();
            let (send, receive) = mpsc::channel::<()>();
            let id = handle
                .post_at(Instant::now() + delay, move || {
                    drop(send);
                    panic!("cancelled job ran");
                })
                .unwrap();
            handle.cancel_scheduled(id);
            handle
                .post(move || {
                    assert_eq!(receive.try_recv(), Err(mpsc::TryRecvError::Disconnected));
                })
                .unwrap();
            handle.shutdown();

            runtime.run();
        }
    }

    #[test]
    fn due_jobs_run_in_deadline_order_with_future_jobs_pending() {
        let (runtime, handle) = MessageThread::new();
        let (send, results) = mpsc::channel();
        let now = Instant::now();
        handle
            .post_at(now + Duration::from_secs(60), || {
                panic!("future job ran early")
            })
            .unwrap();
        let second = send.clone();
        handle
            .post_at(now, move || second.send(2).unwrap())
            .unwrap();
        handle
            .post_at(now - Duration::from_secs(1), move || send.send(1).unwrap())
            .unwrap();
        handle.shutdown();

        runtime.run();
        assert_eq!(results.into_iter().collect::<Vec<_>>(), [1, 2]);
    }
}
