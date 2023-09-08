# Anthem Sequencer

The Anthem engine has two major components: the sequencer and the audio processing graph. Nodes within the audio processing graph can take in events from the sequencer and generate audio for downstream nodes in the audio processing graph. This document will focus on the sequencer and how it provides events for the nodes in the graph.

## Definitions

Before we discuss the Anthem sequencer, I will briefly define some terms.

- **Ticks Per Quarter Note (TPQN):** This term comes from MIDI, and defines the resolution of the sequencer. Each "pulse", defined in this document as a tick, can contain zero or more events across the arrangement, and TPQN defines how many of these ticks occur per beat. If the tempo is 120 BPM and the TPQN is set at 96, then the sequencer will run at a rate of 120 * 96 ticks per minute, or 11520 ticks per minute.
   - Note that "runs at a particular rate" implies that we manage our own clock, which isn't the case for Anthem, or for any other audio software that I'm aware of. We rely on the audio callback from the system audio API, and calculate our timing based on how the current sample and the sample rate as defined by the system API.
- **Tick:** A tick is the smallest unit of time available to the sequencer. Most events in the sequencer have a time, defined as a number of ticks since the start of the pattern, which determines when that event will occur. Arranger clips are the exception; their start times are encoded as ticks since the start of the arrangement.
- **Event:** In this document, an event is defined as any action that can be sent to a generator. These can include note on/off events, automation points, or audio events.
- **Sequencer:** This term is used here to describe a system for arranging and playing back events at specific times. These events can include note on and off events for instruments, audio clip start and stop events, and automation events. In Anthem, the sequencer is responsible for maintaining an in-memory model of the arrangement, and during playback it is responsible for sending the events for the curren tick to their respective generators.
- **Generator:** We use this term to describe a module that can take live or sequenced events and produce data for the audio processing graph. This includes instruments, which take note events and produce audio; automation channels, which take automation events and produce control signals; and audio sequencer channels, which take audio events and produce audio.
- **Pattern:** Anthem is designed to support both track-based and pattern-based workflows, but it uses patterns at its core. Patterns are collections of sequenced events. A pattern can be instanced in the arranger zero or more times as a clip (see below). A clip will simply point to a pattern, so if you have multiple clip instances in the arranger, they will all update if the pattern updates.
- **Clip:** A clip is an instance of a pattern in an arrangement. Clips contain an `offset` value, which represents the time in ticks that the clip starts at relative to the start of the arrangement. Clips can represent a whole pattern or just a slice of a pattern.
- **Arrangement:** An arrangement is a collection of sequenced clips. A project can have multiple arrangements, allowing users to work on new ideas within the same project without affecting the existing sequenced content. All arrangements in a project use the same set of generators and the same audio processing graph, so arrangements are only important to the sequencer.
- **Transport:** The transport is a module that acts as the source of truth for time within the sequencer. It keeps track of the playhead, which marks the tick being currently processed by the sequencer.

## Overview

The sequencer in Anthem is the module responsible for coordinating the propagation of events to audio generators. When an audio generator is told to produce a given number of samples of audio, it traditionally does so with a static state during that processing window. "State" in this case refers to control values, pressed notes, etc.; note that VST3 and similar standards provide an exception to this with sample-accurate automation.

What this means is that audio cannot be generated in chunks that are longer than the tick length, and that audio generator state must be updated before each chunk of audio is generated. This ties the generation of audio to the tick frequency of the sequencer, and also means that the sequencer must drive the audio processing routine, even when the transport is not moving, to allow for live state changes.

The system audio callback delegates to the sequencer, which is the entry point for audio processing. When the sequencer is told to generate a given number of samples, it does the following:

1. **Fill the buffer with leftover samples from the last callback**
   - The system audio API will ask us for samples whenever it needs them. Our sequencer will almost certainly be running at a number of samples per tick that doesn't divide evenly into this number of samples. When this happens, we will always generate a few more samples than we needed for that call, which will roll over into the start of this call.
2. **Inject live events**
   - At the beginning of each processing cycle, we collect all unprocessed live events and set them to be processed on the next tick.
      - Note: we could do this before processing each tick instead. I'm not sure what the tradeoffs are here. I'm sure there are implications on timing, but I have no idea what they are and I'd guess they are minor.
3. **Calculate how many ticks to process**
   - In this step, we calculate how many ticks can fit within the sample window (minus how many samples were rolled over from the last window in step 1), and take the ceiling of that amount.
4. **For each tick we need to process, do the following:**
   1. Query the transport for events on next tick we should process
   2. Send each event to the proper recipient, either generator or audio processor (e.g. FX plugin)
   3. Tell the audio node graph to produce however many samples are needed for this tick
   4. Copy the generated samples from the master out node to the buffer provided by the system audio API; if this is the last tick, only copy the samples that fit, storing the remaining samples for later
   5. Tell the transport to increment by one tick

## Open questions

- In step 3 above, we absolutely cannot simply divide the sample window into how many ticks fit inside and take the ceiling. This is naive and will lead to imprecise timing. The alternative is some sort of math for tracking how the tick interval aligns with the sample rate. I'd like to think more about this.
- It's not yet obvious to me whether tempo automation will fit into this model. I do wonder if tempo automation has to be a special case. I'd like to keep thinking about this.
