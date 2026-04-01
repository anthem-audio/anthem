/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#pragma once

#include <cassert>
#include <cstdint>

// Identifies a deterministic note instance in compiled sequencer data before
// it is translated into a runtime live note ID for downstream processing.
//
// This is deterministic for sequencer notes:
// - For a bare pattern, the source note ID is derived from the pattern note.
// - For an arrangement clip, the source note ID is derived from both the clip
//   and the note so the same pattern note reused in multiple clips produces
//   different source note IDs.
//
using AnthemSourceNoteId = int64_t;

// Identifies a live note request before the live event provider translates it
// into a runtime live note ID.
using AnthemLiveInputNoteId = int64_t;

// Runtime live note IDs are assigned by event providers after they translate a
// source note ID into a concrete emitted note for downstream processors.
//
// This stays 32-bit so it lines up with plugin APIs such as VST3 note IDs.
using AnthemLiveNoteId = int32_t;

inline constexpr AnthemSourceNoteId anthemInvalidSourceNoteId = -1;
inline constexpr AnthemLiveInputNoteId anthemInvalidLiveInputNoteId = -1;
inline constexpr AnthemLiveNoteId anthemInvalidLiveNoteId = -1;

namespace anthem_note_instance_ids {

inline AnthemSourceNoteId fromPatternNoteId(int64_t noteId) {
  assert(noteId >= 0);
  assert(static_cast<uint64_t>(noteId) <= 0xffffffffULL);
  return static_cast<AnthemSourceNoteId>(noteId);
}

inline AnthemSourceNoteId fromArrangementClipNoteId(int64_t clipId, int64_t noteId) {
  // Project entity IDs are currently allocated from a monotonically
  // increasing integer counter in the UI, so packing the clip and note IDs
  // into 64 bits gives us a deterministic source note ID that can be carried
  // through the compiled sequence.
  assert(clipId >= 0);
  assert(noteId >= 0);
  assert(static_cast<uint64_t>(clipId) <= 0xfffffffeULL);
  assert(static_cast<uint64_t>(noteId) <= 0xffffffffULL);

  return static_cast<AnthemSourceNoteId>(((static_cast<uint64_t>(clipId) + 1ULL) << 32) |
                                         (static_cast<uint64_t>(noteId) & 0xffffffffULL));
}

} // namespace anthem_note_instance_ids
