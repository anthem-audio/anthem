# Multi-threaded Audio Processing Design

Anthem has a node-graph-based audio engine. This means that audio routing is modelled as a set of nodes, along with a set of connections that transport audio, control values, or MIDI between nodes. At this level there is no concept of clips, tracks, or sends.

The live processing of this graph is multi-threaded. This speeds up Anthem's audio processing for complex sessions by a factor equal to the number of threads used. If there are 8 threads, audio processing will usually be 8x faster. The more complex a session is, the more opportunities Anthem has to parallelize; in practice, this means that complex sessions are the ones that benefit the most from threading.

For evidence of this, see the demo in `lib/main_scheduler_workbench.dart` and `lib/scheduler_workbench/*`. This demo models complex sessions with worst-case audio routing, and then simulates the threading algorithm used by Anthem to process the session. Very small sessions in this model typically make poor use of threading, but as the track count increases, the thread utilization in this model very often hits ~100%, even in worse-than-usual situations (e.g. many sends across tracks, each of which create a time dependence).

### Algorithm Design

The scheduling algorithm is designed with a specific goal in mind: to always prioritize whatever work is blocking the most other work.

Let's say we have a session with many tracks, and let's say that a few of them look like this:

- Track A acts as a send track for tracks B and C
- Track B has 100 devices on it
- Track C has 2 devices on it

And let's say for the sake of this example that every other track has between 1 and 10 devices.

In this case, track B has the most nodes by far. Track B's processing cannot be parallelized, since each device depends on input from the device before, so only one thread can work on track B at a time. If we were to just pick tracks at random and assign them to threads, we may get unlucky and start track B at the very end, at which point we will be waiting for a single thread to finish processing track B.

The best outcome, then, is to prioritize track B. We cannot have multiple threads work on track B, but we can have a thread always chipping away at track B while other threads take on other tracks.

This track-oriented approach breaks down once you have connections between tracks, so we need a generalized approach to calculate per-node priority, so we can always be working on whichever nodes currently have the highest priorities. To calculate node priorities across the graph, we take the following approach:

To start, we identify all the input nodes in the graph. An input node is a node with no incoming connections. Then, for each input node, we run a recursive priority calculating function. According to this function, a node's priority is equal to the sum priority of all downstream nodes, plus 1. If the node has no downstream nodes, its priority is just 1. Higher numbers mean higher priority.

In our example above, the first node in track B would have a priority of 100 plus downstream nodes (nodes on track A and the master track), while track the first node in track C would have a priority of 2 plus downstream nodes. This means track B will always take priority, and a thread will only pick up work on another track if track B has a worker assigned to it.

This also generalizes to any graph topology. Let's say that track C actually sends into the middle of track B, and then track B sends to track A. Now the beginning nodes of track B are still the most important, but once the first half of track B is processed, track C's nodes will be prioritized since they block further processing of track B.

### Implementation

The implementation for this scheduler relies on the fact that each desktop platform has a way to create very high priority threads. The usage of these threads is treated as real-time-capable by this implementation; an average wake-up as measured by benchmarking (Windows 11, x86/64, MMCSS threads, 1,000,000 wake-ups) was around 0.1 microseconds, 99.9th percentile was 1.7 microseconds, and worst-case across a handful of runs was around 100 microseconds. Even if 1.7 microseconds were the average case, this would still be a viable strategy.

The implementation centers around a simplified mirror of the real node graph model, and a priority queue for ready nodes. The priority queue is gated by an atomic value so that only one thread can access at a time. Synchronization for this is somewhat non-trivial, and is detailed below.

Each time the real graph model changes, a new runtime graph is built. During this rebuild, which is done on the main thread, the following are pre-calculated:
- Node priority
- A list of "starter" nodes, which are nodes with no inputs - these are the first to be added to the priority queue
- Number of inputs per node

Each thread runs a loop that does the following:
1. Tries to acquire a lock for steps 2 - 4; if the lock cannot be acquired after a few attempts, goes to sleep
2. Adds any available ready-to-process nodes to the queue - this reads from all ring buffers in step 5
3. Pulls a node from the queue to process, if one is available; if not, goes to sleep (see below for details)
4. If step 1 is successful and all threads are not awake, wakes another thread
5. Copies from input buffers and processes the node
6. For all downstream nodes, decrements a counter on that node indicating unprocessed inputs - if the counter reaches 0, adds that node to a thread-local ring buffer to indicate it is ready for processing

The tricky part here is that we can't put the primary audio thread to sleep. This means that step 3 actually differs depending on whether the current thread is the primary audio thread or one of the workers:
- For the audio thread, this step must give back an available node if at all possible, unless the graph is finished processing.
- For the other worker threads, they will take an item from the queue only if there are at least two items available.

In addition to this, step 1 has an extra condition: There is a flag indicating whether the audio thread is currently trying to acquire the lock for steps 2 - 4. If this flag is set to true, no other thread will acquire the lock until the audio thread is successful. If this flag is true then the audio thread is spin-waiting, so we want to prioritize it.

This very nearly works to prevent the audio thread from ever waiting on a worker, but unfortunately we cannot guarantee it.

Take the following scenario: Nodes A and B both flow into node C, which is the output node. The audio thread picks up node A, while a worker picks up B. In this case, if B takes 5x as long to process as A, the audio thread will complete first and have no choice but to wait. Since it cannot sleep, it must spin until B is completed, at which point it can pick up node C.
