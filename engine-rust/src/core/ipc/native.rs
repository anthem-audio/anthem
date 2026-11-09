// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

// cspell:ignore nodelay

use super::{Outgoing, message_length, receive};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc::UnboundedReceiver;

pub(super) async fn run(mut outgoing: UnboundedReceiver<Outgoing>) -> std::io::Result<()> {
    let setting =
        |name| std::env::var(name).map_err(|_| std::io::Error::other(format!("Missing {name}")));
    let port: u16 = setting("ANTHEM_ENGINE_PORT")?
        .parse()
        .map_err(std::io::Error::other)?;
    let id: i64 = setting("ANTHEM_ENGINE_ID")?
        .parse()
        .map_err(std::io::Error::other)?;
    let mut socket = TcpStream::connect((std::net::Ipv6Addr::LOCALHOST, port)).await?;
    socket.set_nodelay(true)?;
    socket.write_all(&8u64.to_ne_bytes()).await?;
    socket.write_all(&id.to_ne_bytes()).await?;
    let (mut reader, mut writer) = socket.into_split();
    let read = async {
        loop {
            let mut header = [0; 8];
            reader.read_exact(&mut header).await?;
            let mut body = vec![0; message_length(header)?];
            reader.read_exact(&mut body).await?;
            receive(&body);
        }
        #[allow(unreachable_code)]
        Ok::<(), std::io::Error>(())
    };
    let write = async {
        while let Some(message) = outgoing.recv().await {
            writer.write_all(&message.bytes).await?;
            writer.flush().await?;
            if let Some(flushed) = message.flushed {
                let _ = flushed.send(());
            }
        }
        Ok::<(), std::io::Error>(())
    };
    tokio::select! { result = read => result, result = write => result }
}
