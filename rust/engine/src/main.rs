/*
    Copyright (C) 2021 Joshua Wade

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

// cspell:ignore appender bincode interprocess

use std::io::{BufReader, Read, Write};

use anthem_engine_model::{
    message::{Message, Reply},
    project::Project,
};
use bincode;
use interprocess::local_socket::LocalSocketStream;
use log::{self, debug, error, LevelFilter};
use log4rs::{
    self,
    append::file::FileAppender,
    config::{Appender, Root},
};

fn write(stream: &mut LocalSocketStream, reply: &Reply) {
    let message_bytes = bincode::serialize(reply).unwrap();
    let message_size = message_bytes.len().to_be_bytes();

    stream
        .write_all(&message_size)
        .expect("Failed to write reply to engine.");
    stream
        .write_all(&message_bytes)
        .expect("Failed to write reply to engine.");
}

fn main() {
    let ipc_id = std::env::args().nth(1);

    if ipc_id.is_none() {
        return;
    }

    let ipc_id = ipc_id.unwrap();

    // TODO: This will still create a new file for each project worked on, as
    // well as one for each time the application is opened or a new project is
    // created but not saved. There maybe should at least be some cleanup done
    // on old logs?
    let appender = FileAppender::builder()
        .build(format!("logs/engine-{}.log", ipc_id))
        .expect("Could not build file log appender");

    let _handle = log4rs::init_config(
        log4rs::Config::builder()
            .appender(Appender::builder().build("logger", Box::new(appender)))
            .build(Root::builder().appender("logger").build(LevelFilter::Debug))
            // Probably should handle this more gracefully
            .expect("Could not build logger"),
    )
    .expect("Could not build logger");

    // let listener = LocalSocketListener::bind(format!("\\\\.\\pipe\\{}", ipc_id))
    //     .expect("Could not create local socket");
    // let stream = listener.accept().expect("Could not connect to UI");
    let stream = {
        let result = LocalSocketStream::connect(ipc_id);
        if result.is_err() {
            error!("Could not connect to UI");
        }
        result.expect("Could not connect to UI")
    };
    let mut reader = BufReader::new(stream);

    let mut message_length_buffer = [0u8; 8];

    loop {
        // This uses a really dumb message scheme:
        // 1) read a usize, stating the number of bytes in the incoming message
        // 2) read the number of bytes encoded by the u64
        // The message read out in step 2 is then interpreted as bincode and
        // deserialized via serde into a crate::message::Message.
        reader
            .read_exact(&mut message_length_buffer)
            .expect("Failed to read length header");

        let header_length = usize::from_be_bytes(message_length_buffer);

        let mut message_buffer = vec![0u8; header_length];
        reader
            .read_exact(&mut message_buffer)
            .expect("Failed to read message");

        let message: Message =
            bincode::deserialize(&message_buffer).expect("Message could not be parsed as bincode");

        match message {
            Message::Init => {
                debug!("Initialize processed successfully!");
            }
            Message::Exit => {
                debug!("Exiting...");
                break;
            }

            Message::GetModel => {
                write(reader.get_mut(), &Reply::GetModelReply(Project::default()));
            }
            Message::LoadModel(_project) => {
                // TODO
            }
        }
    }
}
