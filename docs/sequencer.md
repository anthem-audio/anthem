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
- **Pattern:** Anthem is designed to support both track-based and pattern-based workflows, but it uses patterns at its core. Patterns are collections of sequenced events. A pattern can be instanced in the arranger zero or more times as a clip (see below). A clip will simply point to a pattern, so if you have multiple clip instances in the arranger, they will all update if the pattern updates.
- **Clip:** A clip is an instance of a pattern in an arrangement. Clips contain an `offset` value, which represents the time in ticks that the clip starts at relative to the start of the arrangement. Clips can represent a whole pattern or just a slice of a pattern.
- **Arrangement:** An arrangement is a collection of sequenced clips. A project can have multiple arrangements, allowing users to work on new ideas within the same project without affecting the existing sequenced content. All arrangements in a project use the same set of generators and the same audio processing graph, so arrangements are only important to the sequencer.
- **Transport:** The transport is a module that acts as the source of truth for time within the sequencer. It keeps track of the playhead, which marks the tick being currently processed by the sequencer.

## Overview

The sequencer in Anthem is the module responsible for coordinating the propagation of events to audio generators. When an audio generator is told to produce a given number of samples of audio, it traditionally does so with a static state during that processing window. "State" in this case refers to control values, pressed notes, etc.; note that VST3 and similar standards provide an exception to this with sample-accurate automation.

What this means is that audio cannot be generated in chunks that are longer than the tick length, and that audio generator state must be updated before each chunk of audio is generated. This ties the generation of audio to the tick frequency of the sequencer, and also means that the sequencer must drive the audio processing routine, even when the transport is not moving, to allow for live state changes.

The system audio callback delegates to the sequencer, which is the first step in audio processing. The sequener has two roles: the first is to compile the project sequence model into a highly simplified event list for each channel, and the second is to provide these events to the processing graph via a dedicated sequencer node.

When compiling the project sequence, the goal is to produce an event list for each channel that is sorted by offset, and to do so for every pattern and for every arrangement. The goal of this step is to decouple the complexity of the UI from the audio thread. The audio thread should not need to wrangle details of specific user-centric arrangement features.

For example, the project model contains the idea of "clips", or instances of patterns that can be placed throughout the arrangement. This feature exists in the project model, and the compiler reduces the clips in an arrangement down to flat per-channel event lists. The audio thread, then, does not need to have any notion of clips or patterns. This has two advantages. First, advanced features can be developed for sequencing clips, or for any other part of arranging in the UI, without needing to modify the audio code at all, which promotes effective separation of concerns. And second, the simplification of the data as viewed by the audio thread makes it much easier to guarantee predictable performance, as well as to deal with the complexity of performance optimizations that are necessary on the audio thread.

When the sequencer is told to generate a given number of samples, it does the following:

1. For each channel, the sequencer node queries the compiled sequence for events on the next tick that we should process, and writes them to its node ports, which should have been connected to input ports on the associated channels during compilation.
2. The audio node graph is told to produce however many samples are needed for this tick.
3. The sequencer advances the transport by the number of ticks processed, based on the tempo, sample rate, and ticks per quarter note - note that the transport will need to track fractional ticks.

## Open questions

- Tempo automation is not an easy problem, and should be prototyped.
