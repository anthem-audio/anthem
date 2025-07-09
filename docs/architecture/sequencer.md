# Anthem Sequencer

The Anthem engine has two major components: the sequencer and the processing graph. Nodes within the audio processing graph can take in events from the sequencer and generate audio, events or audio-rate control data for downstream nodes in the processing graph. This document will focus on the sequencer and how it provides events for the nodes in the graph.

## Definitions

Before we discuss the Anthem sequencer, I will briefly define some terms.

- **Ticks Per Quarter Note (TPQN):** This term comes from MIDI, and defines the resolution of the sequencer. Each "pulse", defined in this document as a tick, can contain zero or more events across the arrangement, and TPQN defines how many of these ticks occur per beat. If the tempo is 120 BPM and the TPQN is set at 96, then the sequencer will run at a rate of 120 * 96 ticks per minute, or 11520 ticks per minute.
   - Note that "runs at a particular rate" implies that we manage our own clock, which isn't the case for Anthem, or for any other audio software that I'm aware of. We rely on the audio callback from the system audio API, and calculate our timing based on how the current sample and the sample rate as defined by the system API.
- **Tick:** A tick is the smallest unit of time available to the sequencer. Most events in the sequencer have a time, defined as a number of ticks since the start of the pattern, which determines when that event will occur. Arranger clips are the exception; their start times are encoded as ticks since the start of the arrangement.
- **Event:** In this document, an event is defined as any action that can be sent to a generator. These can include note on/off events, automation points, or audio events.
- **Sequencer:** This term is used here to describe a system for arranging and playing back events at specific times. These events can include note on and off events for instruments, audio clip start and stop events, and automation events. In Anthem, the sequencer is responsible for maintaining an in-memory model of the arrangement, and during playback it is responsible for sending the events for the current tick to their respective generators.
- **Generator:** We use this term to describe a module that can take live or sequenced events and produce data for the audio processing graph. This includes instruments, which take note events and produce audio; automation channels, which take automation events and produce control signals; and audio sequencer channels, which take audio events and produce audio.
- **Sequence** A sequence is a collection of events and/or clips of other sequences. Sequences can be composed infinitely, but sequences cannot contain clips of themselves, or do anything else that would create a dependency loop.
- **Clip:** A clip is a window into a sequence that can be placed in another sequence. Clips contain an `offset` value, which represents the time in ticks that the clip starts at relative to the start of the arrangement.
- **Transport:** The transport is a module that acts as the source of truth for time within the sequencer. It keeps track of the playhead, which marks the tick being currently processed by the sequencer.

## Overview

The sequencer in Anthem is the module responsible reading out events from sequences and sending them to live instrument, audio, and automation channels.

The sequencer itself has two roles: the first is to compile each sequence in the project model into a flat event list for each channel, and the second is to provide these events to the processing graph via special sequence event provider nodes. These nodes read the active sequence during playback and feed the processing graph with events for a given channel.

During sequence compilation for a given sequence, the sequencer produces an event list for each channel that is sorted by offset. The goal of this step is to decouple the complexity of the UI from the audio thread. The audio thread should not need to wrangle details of specific user-centric arrangement features.

For example, the project model contains the idea of "sequence composition", or sequences that contain other sequences. This feature exists in the project model, and the compiler reduces the clips in an arrangement down to flat per-channel event lists. The audio thread, then, does not need to have any notion of clips or patterns. This has two advantages. First, advanced features can be developed for sequencing clips, or for any other part of arranging in the UI, without needing to modify the audio code at all, which promotes effective separation of concerns. Second, this makes the actual audio code much easier to write, and it makes it easier to guarantee good performance.

When the sequencer is told to generate a given number of samples, it does the following:

1. The audio node graph is told to produce however many samples are needed for this tick.
2. For each sequence provider node, the node queries the compiled sequence for events within the upcoming processing window, and sends them to the connected downstream nodes.
3. The sequencer advances the transport by the number of ticks processed, based on the tempo, sample rate, and ticks per quarter note - note that the transport will need to track fractional ticks.

## Open questions

- Tempo automation is not an easy problem, and should be prototyped.
