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

use crate::commands::command::Command;
use crate::model::{generator::Controller, generator::Instrument, project::Project, store::Reply};

fn remove_generator(project: &mut Project, id: u64) {
    project
        .generator_list
        .retain(|generator_id| *generator_id != id);
    project
        .instruments
        .retain(|instrument_id, _| *instrument_id != id);
    project
        .controllers
        .retain(|controller_id, _| *controller_id != id);
}

pub struct AddInstrumentCommand {
    pub id: u64,
    pub name: String,
}

impl Command for AddInstrumentCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        project.generator_list.push(self.id);
        project.instruments.insert(
            self.id,
            Instrument {
                id: self.id,
                name: self.name.clone(),
            },
        );
        vec![Reply::InstrumentAdded(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        remove_generator(project, self.id);
        vec![Reply::GeneratorRemoved(request_id)]
    }
}

pub struct AddControllerCommand {
    pub id: u64,
    pub name: String,
}

impl Command for AddControllerCommand {
    fn execute(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        project.generator_list.push(self.id);
        project.controllers.insert(
            self.id,
            Controller {
                id: self.id,
                name: self.name.clone(),
            },
        );
        vec![Reply::ControllerAdded(request_id)]
    }

    fn rollback(&self, project: &mut Project, request_id: u64) -> Vec<Reply> {
        remove_generator(project, self.id);
        vec![Reply::GeneratorRemoved(request_id)]
    }
}
