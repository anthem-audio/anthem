use rid::RidStore;

#[rid::store]
#[rid::structs(Project)]
#[derive(Debug)]
pub struct Store {
    projects: Vec<Project>,
}

// #[rid::model]
// #[derive(Debug)]
// pub struct Counter {
//     count: u32,
// }

#[rid::model]
#[derive(Clone, Debug)]
pub struct Project {}

impl RidStore<Msg> for Store {
    fn create() -> Self {
        Self {
            // counter: Counter { count: 0 },
            projects: [Project {}].to_vec(),
        }
    }

    fn update(&mut self, req_id: u64, msg: Msg) {
        match msg {
            Msg::Noop => {
                rid::post(Reply::Noop(req_id))
            }
            // Msg::Inc => {
            //     self.counter.count += 1;
            //     rid::post(Reply::Increased(req_id));
            // }
            // Msg::Add(n) => {
            //     self.counter.count += n;
            //     rid::post(Reply::Added(req_id, n.to_string()));
            // }
        }
    }
}

#[rid::message(Reply)]
#[derive(Debug)]
pub enum Msg {
    Noop,
    // Inc,
    // Add(u32),
}

#[rid::reply]
pub enum Reply {
    Noop(u64),
    // Increased(u64),
// Added(u64, String),
}
