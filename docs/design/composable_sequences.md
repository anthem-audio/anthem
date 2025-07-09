# Composable Sequences

This document describes Anthem's approach to sequencing workflows. Anthem presents a linear workflow as the default and most discoverable option, but provides advanced sequencing capability in the form of composable sequences, inspired by pattern-based workflows from other DAWs.

## Background

Anthem has usability as a core design goal. For this reason, Anthem presents a linear, track-based workflow as the default, and makes it the most discoverable. We want a first-time user to be able to add an audio track and immediately record audio into that track, and when they open the mixer, we want the signal flow to be self-evident.

If you have only used DAWs with this linear workflow style, this may seem obvious; however, at its core Anthem's sequencer is fundamentally non-linear, which makes its default linear workflow unique. If you are instead already used to a pattern-based or similar workflow, you may not immediately see the point in presenting a linear workflow at all.

### Defining linear workflow

For the purpose of this document, "linear workflow" means that each instrument occupies a single track and creates a single mixer channel. Strictly speaking, a linear workflow would only allow events destined for a given channel to be placed within that channel's row in any sequencer view. This may differ from the way the term is used elsewhere, so it is worth defining here.

### Defining pattern-based workflow

For the purpose of this document, a pattern-based workflow is one where there are two types of sequence, patterns and arrangements. Patterns are containers that can hold timestamped events for any kind of track (audio, instrument plug-in, automation), and pattern instances (sometimes called clips) can be placed at various start times in the arrangement.

### Anthem, a multi-workflow DAW

Anthem is multi-workflow, meaning that Anthem is designed to serve a wide range of reasons why someone might reach for a DAW.

For example, if you only ever want to do multi-track audio recording or editing, the current state-of-the-art pattern-based workflow is deeply confusing, at least to a new user. Let's say I record a few audio clips. I want to change the volume of the audio I just recorded, but there seems to be nowhere to do that? Or, if I even realize that each audio clip maps to a channel - and this is not at all obvious - maybe I'm now annoyed that I have to turn down each channel, and wonder why I can't turn them down all at once?

Most DAWs have mixers, so if you're used to this workflow you might expect me to intuit the solution here (route each new channel to the same mixer track, then change the mixer track volume); but most DAWs also allow you to record multiple audio clips into a single track, and add effects directly onto that track. And what if this is my first time picking up a DAW? It's hard to overstate how much complexity a pattern-based DAW requires you to learn before it stops getting in your way.

However, if what you're creating relies on heavy and/or creative use of the sequencer, a strictly linear workflow likely won't be the most productive. There are many ways to augment a linear workflow from a composition standpoint (track folders are a great example), but there is a flexibility to a pattern-based workflow that is indispensable for some people. If anything can go anywhere in the sequencer timeline, and if any sound or automation source can route to any destination, it creates a flexibility that is incredibly useful for advanced, sound-design-heavy workflows.

### Limitations of pattern-based workflows

For all the difficulty given above to the new user experience of pattern-based workflows, DAWs with this workflow have a particularly difficult usability challenge. If you must place an event in a pattern, then a pattern in an arrangement in order to do anything useful with the sequencer, then many common actions become disjointed and difficult to reason about.

For example, suppose that all automation must live in a pattern, and can only be edited within the pattern context. In this case, if I want to add a single automation lane for a global control in my arrangement (e.g. a gain parameter on the master channel), I cannot modify the events for that from within the arrangement, and so I cannot see and edit the automation changes in context with the rest of the events in the project. In cases like this, a purist pattern-style workflow would kill usability.

As of writing, the most popular pattern-based DAW is FL Studio. FL Studio solves this by restricting what content can go in patterns. While some kinds of automation can end up in a regular pattern, there are special patterns for audio and automation, and these patterns can only contain events for a single channel. With these limitations, FL Studio enables workflow enhancements that turn what would be a clunky-but-powerful workflow into something that is both powerful and highly efficient to work in, once you learn it.

However, these limitations limit the degree to which similar events can be grouped into containers. If the primary way I sequence audio is through single-shot audio patterns, there is no way to group multiple recordings together from a sequence perspective. This requires me to do all my chopping and resampling within the arrangement context instead of the pattern context. This is usually beneficial as it removes unnecessary steps; however, sometimes a given set of audio clips, a complex drum beat for example, may get to a level of complexity to where I want to put it in a container, and FL Studio just doesn't effectively enable this at a certain level.

And this could extend to other event types like notes and automation as well. Maybe I have a complex sequence of automation clips that only goes with a given set of notes. If I later want to move just those notes, I have to remember which automation clips go with which other events, otherwise I will break my sequence. Besides providing the ability to group my arrangement clips in a way that might allow me to remember what goes with what, FL Studio doesn't provide an effective way to manage this problem. Past a certain level of arrangement complexity, this poses a usability issue that FL Studio cannot effectively solve.

### The philosophy behind Anthem's sequencer design

Anthem's sequencer could be considered fundamentally pattern-based at its core, though its workflow does not fall under the definition of pattern-based as [defined above](#defining-pattern-based-workflow).

Instead of embracing sequence composition as the primary workflow (as in FL Studio's sequence-in-sequence workflow of putting patterns inside arrangements), Anthem presents sequence composition as an advanced workflow that can be simply ignored if the user does not prefer to work this way. This design has a couple distinct advantages:

1. Linear workflow is easier for many people to learn and work in, especially for those doing multi-track recording or stem mixing. By fully enabling this workflow, Anthem can provide enhancements like comping to the audio recording workflow. Comping is critical for some workflows, but it's something FL Studio has traditionally struggled with.
2. By embracing sequence composition as an advanced workflow, Anthem can dramatically expand the scope of what patterns can do without harming core usability stories. To take the example of project-wide automation above, if I want a global automation clip for a gain control, I can simply add a new linear track for it. With this in mind, automation in patterns can be reserved for complex use-cases where it is most helpful.

## Design

Anthem's sequencer presents a linear workflow (see [the definition above](#defining-linear-workflow)), but has advanced features that allow users to break out of this if and when they prefer.

Anthem's linear workflow has the following characteristics:

- A new instrument means a new track, and a track shows up as a first-class element everywhere that a track is relevant (all sequence editors, the mixer, etc.)
- Clips supply events to a single track by default, and it shouldn't be easy to break out of this workflow by accident

Anthem's linear workflow is designed to support advanced linear features, like track comping. When editing the contents of a single audio track, Anthem has the option to present any kind of workflow enhancement that would be common in this environment, due to its flexible internal design.

There are two primary features that work together to enable more advanced workflows in Anthem.

The first is that internally, any sequence in Anthem can contain events for any channel. For example, when you create a midi clip for a channel in a linear workflow, there is a real sequence underneath, and Anthem's UI is artificially limiting what you are allowed to put in that. Anthem has a special kind of track, called a "free track", that allows clips for any kind of sequence. This includes sequences that contain content for multiple real destinations, called "channels".

The second is that sequences can contain clips of other sequences. This is called "sequence composition", and is used to enable a number of features both in the ordinary linear workflow as well as the more free-form sequence composition workflow.

A full anything-can-go-anywhere workflow is available to users if they choose; however, sequence composition is used as a way to implement advanced features in the linear workflow as well. For example, every midi clip is a window into a completely separate sequence. When the piano roll is opened for that clip, it is editing the underlying sequence. This allows the clip to be resized and repositioned without affecting the source of truth for the piano roll.

This separation of clips from the underlying sequence also enables a traditional pattern-based workflow. Anthem does not enable this by default - instead, copying a clip also duplicates the sequence underneath. However, Anthem does support "linked clips", in which multiple clips can point to the same underlying sequence. Anthem intends this to be obvious to the user at every level; when the user edits the content of a sequence and it propagates to multiple clips in a different sequence, it should not be a surprise.

### Workflow design concepts

Below are a few specific workflow stories that are enabled by Anthem's core sequencer design. None of these should be taken as feature commitments at this stage; they are instead intended to exercise the possibilities enabled by Anthem's unique sequencer design.

#### Creating a new composed sequence from an group of clips

One of the benefits of sequence composition as a workflow is that it allows you to compose highly complex projects out of simpler building blocks.

Let's say I want to make a drum loop, and I want to compose it of many samples across multiple channels. From a workflow perspective, I likely do not care about the detailed sequencing of this loop when viewing the project timeline. In most DAWs, my options are limited here. I can bounce the drum loop to audio, but this is a destructive action that makes it harder to modify the loop later.

In Anthem, if working in a linear workflow, I may prefer to use a more linear-centric feature like track folders. However, if I am currently sequencing in free tracks, one option Anthem could provide is a right-click option or shortcut to create a composed sequence out of a selected group of clips. This would be similar to "grouping" in vector graphics editors.

How this would interact with content from regular tracks is unclear. It may be that it must be moved to a free track before this is possible, otherwise it may feel too arbitrary, and it would be difficult to manually reverse.

#### Shaping your arrangement views

Taking the drum loop example from above, let's say I already have a sequence that contains my drum loop. If I am editing that sequence, I may only care about content from a few channels when editing that sequence. It may be helpful to have an option to limit the current sequencer view to only tracks that are currently in use.

It may also be useful to completely separate regular tracks from free tracks. This one is less clear to me though - I could imagine a workflow where someone puts only a handful of intentionally-placed free tracks within a large project, and I could see that being a very useful workflow. However, in this case, the user likely does not want to see all tracks, just the ones with content. This is another argument for hiding tracks that don't contribute to the active sequence.

#### Multi-track sequence quick expansion and editing

Traditional patterns become unwieldy very quickly. It becomes difficult to reason about the content of a clip once it contains overlapping content of the same type for different sources, such as multiple distinct automation lanes. This would discourage some important use-cases, and so should be mitigated.

Given a clip that contains content for multiple different channels, an option could be given to "expand" this clip. This would:
1. Highlight the clip itself
2. (Maybe) Highlight the time region that the clip occupies (or regions, in the case of linked clips)
3. Beneath the track that the clip occupies, expand new track rows for each track in the clip that actually contains content
4. Allow granular editing of the content within those tracks. If one of those tracks itself contains such a multi-content clip, it could possibly itself be further expanded.
