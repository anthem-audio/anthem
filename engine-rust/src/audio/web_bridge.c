/* Copyright (C) 2026 Joshua Wade
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include <emscripten.h>
#include <emscripten/webaudio.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

enum { output_channels = 2 };
static const char processor_name[] = "anthem-audio";

// Emscripten registers thread metadata in this stack. The context and stack
// belong to the module and are reused for each audio session.
static _Alignas(16) unsigned char worklet_stack[1024 * 1024];
static EMSCRIPTEN_WEBAUDIO_T context;
static EMSCRIPTEN_WEBAUDIO_T node;
static atomic_bool initializing;
static atomic_bool closing;
// Zero while preparing, positive sample rate when ready, negative on failure.
static atomic_int sample_rate;
// Zero while closing, 1 after successful close, -1 on failure.
static atomic_int close_result;
static _Atomic(uintptr_t) renderer;
static atomic_bool in_callback;

extern void anthem_render_audio(void* state, float* output, unsigned frames);

static bool process(int input_count, const AudioSampleFrame* inputs,
                    int output_count, AudioSampleFrame* outputs,
                    int param_count, const AudioParamFrame* params, void* data) {
    (void)input_count;
    (void)inputs;
    (void)param_count;
    (void)params;
    (void)data;
    // Sequential consistency pairs this gate with detach on the message
    // thread. A callback either sees the null pointer or is counted in flight.
    atomic_store(&in_callback, true);
    void* state = atomic_load(&closing) ? NULL : (void*)atomic_load(&renderer);
    for (int i = 0; i < output_count; ++i) {
        AudioSampleFrame* output = &outputs[i];
        if (!output->data || output->samplesPerChannel <= 0) continue;
        if (state && output_count == 1 && output->numberOfChannels == output_channels) {
            anthem_render_audio(state, output->data, output->samplesPerChannel);
        } else {
            memset(output->data, 0,
                   output->numberOfChannels * output->samplesPerChannel * sizeof(float));
        }
    }
    atomic_store(&in_callback, false);
    return true;
}

static void preparation_failed(void) {
    atomic_store(&sample_rate, -1);
}

static void processor_failed(void) {
    // The browser stops invoking process after an uncaught worklet exception.
    // If it interrupted the callback, release any detach waiting on it.
    atomic_store(&in_callback, false);
    atomic_store(&sample_rate, -1);
}

static void processor_created(EMSCRIPTEN_WEBAUDIO_T audio_context, bool success, void* data) {
    (void)data;
    if (atomic_load(&closing)) return;
    if (!success) {
        preparation_failed();
        return;
    }
    int channels[] = { output_channels };
    EmscriptenAudioWorkletNodeCreateOptions options = {0};
    options.numberOfOutputs = 1;
    options.outputChannelCounts = channels;
    options.channelCount = output_channels;
    options.channelCountMode = WEBAUDIO_CHANNEL_COUNT_MODE_EXPLICIT;
    node = emscripten_create_wasm_audio_worklet_node(
        audio_context, processor_name, &options, process, NULL);
    if (!node) {
        preparation_failed();
        return;
    }
    EM_ASM({
        emscriptenGetAudioObject($0).addEventListener('processorerror', () => {
            getWasmTableEntry($1)();
        });
    }, node, processor_failed);
    emscripten_audio_node_connect(node, audio_context, 0, 0);
    atomic_store(&sample_rate, emscripten_audio_context_sample_rate(audio_context));
}

static void thread_initialized(EMSCRIPTEN_WEBAUDIO_T audio_context, bool success, void* data) {
    (void)data;
    if (atomic_load(&closing)) return;
    if (!success) {
        preparation_failed();
        return;
    }
    WebAudioWorkletProcessorCreateOptions options = {0};
    options.name = processor_name;
    emscripten_create_wasm_audio_worklet_processor_async(
        audio_context, &options, processor_created, NULL);
}

static int is_active(void) {
    return atomic_load(&renderer) != 0 && !atomic_load(&closing);
}

static void prepare_on_main(void) {
    if (atomic_load(&closing)) return;
    EmscriptenWebAudioCreateAttributes options = {0};
    options.latencyHint = "interactive";
    context = emscripten_create_audio_context(&options);
    // Browser activation must be handled in the event itself. This listener
    // also covers a context that was prepared before the first click.
    EM_ASM({
        const audio = emscriptenGetAudioObject($0);
        // Preparation can outlive a cancelled start. Keep the context
        // suspended until a renderer is attached.
        audio.suspend().catch(() => {});
        const resume = () => {
            if (audio.state === 'suspended' && getWasmTableEntry($1)()) {
                audio.resume().catch(() => {});
            }
        };
        document.addEventListener('click', resume, true);
        document.addEventListener('keydown', resume, true);
        audio.addEventListener('statechange', () => {
            if (audio.state === 'closed') {
                document.removeEventListener('click', resume, true);
                document.removeEventListener('keydown', resume, true);
            }
        });
    }, context, is_active);
    emscripten_start_wasm_audio_worklet_thread_async(
        context, worklet_stack, sizeof worklet_stack, thread_initialized, NULL);
}

void anthem_web_audio_prepare(void) {
    if (atomic_exchange(&initializing, true)) return;
    MAIN_THREAD_ASYNC_EM_ASM({
        try {
            getWasmTableEntry($0)();
        } catch (error) {
            console.error('Could not initialize Anthem audio', error);
            getWasmTableEntry($1)();
        }
    }, prepare_on_main, preparation_failed);
}

int anthem_web_audio_sample_rate(void) {
    return atomic_load(&sample_rate);
}

static void update_context_on_main(void) {
    if (!context || atomic_load(&closing)) return;
    EM_ASM({
        const audio = emscriptenGetAudioObject($0);
        const update = $1 ? audio.resume() : audio.suspend();
        update.catch(() => {});
    }, context, is_active());
}

void anthem_web_audio_attach(void* state) {
    atomic_store(&renderer, (uintptr_t)state);
    MAIN_THREAD_ASYNC_EM_ASM({ getWasmTableEntry($0)(); }, update_context_on_main);
}

void anthem_web_audio_detach(void) {
    atomic_store(&renderer, 0);
    MAIN_THREAD_ASYNC_EM_ASM({ getWasmTableEntry($0)(); }, update_context_on_main);
}

int anthem_web_audio_in_callback(void) {
    return atomic_load(&in_callback);
}

static void release_context_handle(void) {
    emscripten_destroy_audio_context(context);
    context = 0;
}

static void close_completed(int success) {
    atomic_store(&close_result, success ? 1 : -1);
}

static void close_on_main(void) {
    if (node) {
        emscripten_destroy_web_audio_node(node);
        node = 0;
    }
    if (!context) {
        close_completed(1);
        return;
    }
    EM_ASM({
        const audio = emscriptenGetAudioObject($0);
        // Destroying the Emscripten handle calls suspend(). Release it while
        // suspended and retain the JS context until close() completes.
        audio.suspend().then(() => {
            getWasmTableEntry($1)();
            return audio.close();
        }).then(() => getWasmTableEntry($2)(1), (error) => {
            console.error('Could not close Anthem audio', error);
            getWasmTableEntry($2)(0);
        });
    }, context, release_context_handle, close_completed);
}

void anthem_web_audio_close(void) {
    if (atomic_exchange(&closing, true)) return;
    atomic_store(&renderer, 0);
    MAIN_THREAD_ASYNC_EM_ASM({ getWasmTableEntry($0)(); }, close_on_main);
}

int anthem_web_audio_close_result(void) {
    return atomic_load(&close_result);
}
