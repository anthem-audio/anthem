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

// cspell:ignore interprocess bincode

use std::{
    io::{BufReader, Write},
    process::Stdio,
};

use anthem_engine_model::message::Message;
use interprocess::local_socket::{LocalSocketListener, LocalSocketStream};

pub struct EngineBridge {
    connection: BufReader<LocalSocketStream>,
}

impl EngineBridge {
    pub fn new(id: &String) -> EngineBridge {
        // TODO: Softer error handling
        // let stream = LocalSocketStream::connect(format!("\\\\.\\pipe\\{}", id.clone()))
        //     .expect("Failed to connect to engine");
        // let reader = BufReader::new(stream);
        let listener =
            LocalSocketListener::bind(id.clone()).expect("Could not create local socket");

        std::process::Command::new(
            &std::path::Path::new("data")
                .join("flutter_assets")
                .join("assets")
                .join("build")
                .join("anthem_engine")
                .to_str()
                .unwrap(),
        )
        .arg(id)
        // Connecting the new process to stdout in this process causes the Flutter
        // dev connection to break
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("Failed to start engine");

        let stream = listener.accept().expect("Could not connect to UI");
        let reader = BufReader::new(stream);

        EngineBridge { connection: reader }
    }

    pub fn send(&mut self, message: &Message) {
        let message_bytes = bincode::serialize(message).unwrap();
        let message_size = message_bytes.len().to_be_bytes();

        self.connection
            .get_mut()
            .write_all(&message_size)
            .expect("Could not write to engine");
        self.connection
            .get_mut()
            .write_all(&message_bytes)
            .expect("Could not write to engine");
    }
}
