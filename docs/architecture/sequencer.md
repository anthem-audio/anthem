# Anthem Sequencer

The Anthem engine has two major components: the sequencer and the processing graph. Nodes within the audio processing graph can take in events from the sequencer and generate audio, events or audio-rate control data for downstream nodes in the processing graph. This document will focus on the sequencer and how it provides events for the nodes in the graph.

## Definitions

- **Ticks Per Quarter Note (TPQN):** This term comes from MIDI, and defines time for the sequencer. Ticks occur at a rate determined by the current tempo. TPQN defines how many of these ticks occur per beat. If the tempo is 120 beats per minute and the TPQN is set at 96, then the sequencer will run at a rate of 120 * 96 ticks per minute, or 11520 ticks per minute.
- **Tick:** A tick is an arbitrary unit of time whose duration is defined by the current tempo. Events in the sequencer have a time, defined as a floating-point number of ticks since the start of the sequence, which determines when that event will occur.
- **Event:** An event is defined as any action that can be sent to a track. These can include note on/off events, automation points, or audio events.
- **Sequencer:** This term is used here to describe a system for arranging and playing back events at specific times. These events can include note on and off events for instruments, audio clip start and stop events, and automation events. In Anthem, the sequencer is responsible for maintaining an in-memory model of the arrangement, and during playback it is responsible for sending the events for the current tick to their respective generators.
- **Sequence** A sequence is a collection of events and/or clips of other sequences. Sequences can be composed infinitely, but sequences cannot contain clips of themselves, or do anything else that would create a dependency loop.
- **Clip:** A clip is a window into a sequence that can be placed in another sequence.
- **Transport:** The transport is a module that acts as the source of truth for time within the sequencer. It keeps track of the playhead, which marks the current time in the sequence.

## Overview

The sequencer in Anthem is responsible reading out events from sequences and sending them to tracks. It is implemented by components in the UI, data model, and engine.

## Data model

Anthem has tracks, which represent places where events can be sent. Sequences are collections of these events, and possibly clips of other sequences.

Sequences may have one or more clips associated with them. Clips are windows into a sequence, and are owned by a parent sequence (usually an arrangement). They have a start and end time within the sequence that they target, and they have an offset from the start of whatever sequence owns them. They also may be associated with a track, which defines where raw events will be sent.

The arrangement is itself a sequence. It does not directly contain events, but instead contains only clips of other sequences.

Multiple clips can exist of a given sequence, which allows complex sequence linking behavior. This includes traditional pattern-style workflows, but also allows for the same sequence to appear in multiple clips on different instruments.

## Engine implementation

The sequencer module in the engine has two roles: The first is to compile each sequence in the project model into a flat event list for each channel, and the second is to provide these events to the processing graph via special sequence event provider nodes. These nodes read the active sequence during playback and feed the processing graph with events for a given channel.

During sequence compilation for a given sequence, the sequencer produces an event list for each channel that is sorted by offset. The goal of this step is to decouple the complexity of the UI from the audio thread. The audio thread should not need to wrangle details of specific user-centric arrangement features.

For example, the project model allows sequences to contain clips of other sequences. This feature exists in the project model, and the compiler reduces all the events in a given sequence down to flat per-track event lists. The audio thread, then, does not need to have any notion of clips or patterns. This has two advantages. First, advanced features can be developed for sequencing clips, or for any other part of arranging in the UI, without needing to modify the audio code at all, which promotes effective separation of concerns. Second, this makes the actual audio code much easier to write, and it makes it easier to guarantee good performance.

When the sequencer is told to generate a given number of samples, it does the following:

1. The audio node graph is told to produce however many samples are needed for this tick.
2. For each sequence provider node, the node queries the compiled sequence for events within the upcoming processing window, and sends them to the connected downstream nodes.
3. The sequencer advances the transport by the number of ticks processed, based on the tempo, sample rate, and ticks per quarter note - note that the transport will need to track fractional ticks.
