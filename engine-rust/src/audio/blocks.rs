// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use super::BLOCK_FRAMES;

/// Adapts variable-sized device callbacks to fixed-size graph blocks.
///
/// The adapter allocates one scratch block before audio starts and keeps
/// any unused frames for the next device callback.
pub(super) struct FixedBlocks {
    block: Box<[f32]>,
    channels: usize,
    consumed: usize,
}

impl FixedBlocks {
    pub(super) fn new(channels: usize) -> Self {
        Self {
            block: vec![0.0; BLOCK_FRAMES * channels].into_boxed_slice(),
            channels,
            consumed: BLOCK_FRAMES,
        }
    }

    /// Supplies exactly `frames` frames for the current device callback.
    ///
    /// Calls `render_block` to fill `BLOCK_FRAMES` frames of interleaved
    /// samples whenever there are no buffered frames left. A request may
    /// use only leftover frames or span several graph blocks.
    ///
    /// Calls `write_frames` with the destination offset in frames from the
    /// start of the device buffer and a slice of interleaved samples. The
    /// backend copies the samples into its output format.
    pub(super) fn write(
        &mut self,
        frames: usize,
        mut render_block: impl FnMut(&mut [f32]),
        mut write_frames: impl FnMut(usize, &[f32]),
    ) {
        let mut written = 0;
        while written < frames {
            if self.consumed == BLOCK_FRAMES {
                render_block(&mut self.block);
                self.consumed = 0;
            }
            let count = (frames - written).min(BLOCK_FRAMES - self.consumed);
            let start = self.consumed * self.channels;
            let end = start + count * self.channels;
            write_frames(written, &self.block[start..end]);
            self.consumed += count;
            written += count;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn renders_whole_blocks_and_preserves_samples_across_device_callbacks() {
        let mut adapter = FixedBlocks::new(2);
        let mut next_sample = 0;
        let mut actual = Vec::new();
        for frames in [0, 64, 192, 1, 255] {
            adapter.write(
                frames,
                |block| {
                    assert_eq!(block.len(), BLOCK_FRAMES * 2);
                    for sample in block {
                        *sample = next_sample as f32;
                        next_sample += 1;
                    }
                },
                |_, samples| actual.extend_from_slice(samples),
            );
        }
        assert!(actual.into_iter().eq((0..1024).map(|sample| sample as f32)));
        assert_eq!(next_sample, 1024);
    }
}
