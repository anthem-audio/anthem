use std::process::Stdio;

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

pub fn start_engine(id: &String) {
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
    
    // Connecting this process to our stdout causes the Flutter dev connection
    // to break
    .stdin(Stdio::null())
    .stdout(Stdio::null())
    .stderr(Stdio::null())

    .spawn()
    .expect("Failed to start engine");
}
