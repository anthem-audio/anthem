/*
    Copyright (C) 2022 Joshua Wade

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

use std::ops::DerefMut;

use anyhow::{anyhow, Result};

use flutter_rust_bridge::ZeroCopyBuffer;
use lazy_static::__Deref;
use tfc::{MouseContext, ScreenContext};

use crate::{
    dependencies::engine_model::{
        message::{Reply, Request, RequestWrapper},
        util::get_id,
    },
    engine_bridge::EngineBridge,
    state::{INPUT_CTX, STATE},
};

// Anthem code

// TODO: error handling
pub fn start_engine(id: i64) -> Result<()> {
    let bridge = EngineBridge::new(&id.to_string());
    STATE.lock().unwrap().engine_processes.insert(id, bridge);
    Ok(())
}

// TODO: error handling
pub fn stop_engine(id: i64) -> Result<()> {
    STATE.lock().unwrap().engine_processes.remove(&id);
    Ok(())
}

// TODO: error handling
// TODO: full duplex
pub fn send(engine_id: i64, request: Request) -> Result<Option<Reply>> {
    let mut state = STATE.lock().unwrap();
    let engine = state.engine_processes.get_mut(&engine_id).unwrap();
    engine.send(&RequestWrapper::new(get_id(), request));
    let reply_wrapper = engine.receive();
    Ok(reply_wrapper.reply)
}

// Mouse handling

pub struct MousePos {
    pub x: i32,
    pub y: i32,
}

pub fn get_mouse_pos() -> Result<MousePos> {
    let ctx_mutex = match INPUT_CTX.lock() {
        Ok(mutex) => mutex,
        Err(_) => return Err(anyhow!("get_mouse_pos(): mutex lock failed")),
    };
    let ctx = ctx_mutex.deref();
    let loc = match ctx.cursor_location() {
        Ok(loc) => loc,
        Err(_) => return Err(anyhow!("get_mouse_pos(): ctx.cursor_location() failed")),
    };
    Ok(MousePos { x: loc.0, y: loc.1 })
}

pub fn set_mouse_pos(x: i32, y: i32) -> Result<()> {
    let mut ctx_mutex = match INPUT_CTX.lock() {
        Ok(mutex) => mutex,
        Err(_) => return Err(anyhow!("set_mouse_pos(): mutex lock failed")),
    };
    let ctx = ctx_mutex.deref_mut();
    match ctx.mouse_move_abs(x, y) {
        Err(_) => return Err(anyhow!("get_mouse_pos(): ctx.move_mouse_abs() failed")),
        _ => {}
    }
    Ok(())
}

// Example code (TODO: remove)

//
// NOTE: Please look at https://github.com/fzyzcjy/flutter_rust_bridge/blob/master/frb_example/simple/rust/src/api.rs
// to see more types that this code generator can generate.
//

pub fn draw_mandelbrot(
    image_size: Size,
    zoom_point: Point,
    scale: f64,
    num_threads: i32,
) -> Result<ZeroCopyBuffer<Vec<u8>>> {
    // Just an example that generates "complicated" images ;)
    let image = crate::off_topic_code::mandelbrot(image_size, zoom_point, scale, num_threads)?;
    Ok(ZeroCopyBuffer(image))
}

pub fn passing_complex_structs(root: TreeNode) -> Result<String> {
    Ok(format!(
        "Hi this string is from Rust. I received a complex struct: {:?}",
        root
    ))
}

#[derive(Debug, Clone)]
pub struct Size {
    pub width: i32,
    pub height: i32,
}

#[derive(Debug, Clone)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone)]
pub struct TreeNode {
    pub name: String,
    pub children: Vec<TreeNode>,
}

// following are used only for memory tests. Readers of this example do not need to consider it.

pub fn off_topic_memory_test_input_array(input: Vec<u8>) -> Result<i32> {
    Ok(input.len() as i32)
}

pub fn off_topic_memory_test_output_zero_copy_buffer(len: i32) -> Result<ZeroCopyBuffer<Vec<u8>>> {
    Ok(ZeroCopyBuffer(vec![0u8; len as usize]))
}

pub fn off_topic_memory_test_output_vec_u8(len: i32) -> Result<Vec<u8>> {
    Ok(vec![0u8; len as usize])
}

pub fn off_topic_memory_test_input_vec_of_object(input: Vec<Size>) -> Result<i32> {
    Ok(input.len() as i32)
}

pub fn off_topic_memory_test_output_vec_of_object(len: i32) -> Result<Vec<Size>> {
    let item = Size {
        width: 42,
        height: 42,
    };
    Ok(vec![item; len as usize])
}

pub fn off_topic_memory_test_input_complex_struct(input: TreeNode) -> Result<i32> {
    Ok(input.children.len() as i32)
}

pub fn off_topic_memory_test_output_complex_struct(len: i32) -> Result<TreeNode> {
    let child = TreeNode {
        name: "child".to_string(),
        children: Vec::new(),
    };
    Ok(TreeNode {
        name: "root".to_string(),
        children: vec![child; len as usize],
    })
}

pub fn off_topic_deliberately_return_error() -> Result<i32> {
    std::env::set_var("RUST_BACKTRACE", "1"); // optional, just to see more info...
    Err(anyhow!("deliberately return Error!"))
}

pub fn off_topic_deliberately_panic() -> Result<i32> {
    std::env::set_var("RUST_BACKTRACE", "1"); // optional, just to see more info...
    panic!("deliberately panic!")
}
