use rid_build::{build, BuildConfig, BuildTarget, FlutterConfig, FlutterPlatform, Project};
use std::{env, fs, path::Path, process::Command};

fn main() {
    build_anthem_engine();

    let crate_dir = env::var("CARGO_MANIFEST_DIR")
        .expect("Missing CARGO_MANIFEST_DIR, please run this via 'cargo run'");

    let workspace_dir = &crate_dir;

    let crate_name = &env::var("CARGO_PKG_NAME")
        .expect("Missing CARGO_PKG_NAME, please run this via 'cargo run'");
    let lib_name = &if cfg!(target_os = "windows") {
        format!("{}", &crate_name)
    } else {
        format!("lib{}", &crate_name)
    };

    let build_config = BuildConfig {
        target: BuildTarget::Debug,
        project: Project::Flutter(FlutterConfig {
            plugin_name: "plugin".to_string(),
            platforms: vec![
                // NOTE: Remove any of the below platforms that you don't support

                // Mobile
                FlutterPlatform::ios(),
                FlutterPlatform::android(),
                // Desktop
                FlutterPlatform::macos(),
                FlutterPlatform::linux(),
            ],
        }),
        lib_name,
        crate_name,
        project_root: &crate_dir,
        workspace_root: Some(&workspace_dir),
    };
    build(&build_config).expect("Build failed");
}

fn build_anthem_engine() {
    fs::create_dir("./build").ok();
    fs::create_dir("./target").ok();

    let crate_dir = env::var("CARGO_MANIFEST_DIR")
        .expect("Missing CARGO_MANIFEST_DIR, please run this via 'cargo run'");
    let engine_repo_dir_path = Path::new(&crate_dir).join("build").join("anthem_engine");
    let engine_repo_dir = engine_repo_dir_path.to_str().unwrap();
    let engine_cargo_file_path = engine_repo_dir_path.join("Cargo.toml");
    let engine_cargo_file = engine_cargo_file_path.to_str().unwrap();
    let engine_out_dir_path = Path::new(&crate_dir).join("assets").join("build");
    let engine_out_dir = engine_out_dir_path.to_str().unwrap();

    let clone_result = Command::new("git")
        .args([
            "clone",
            "https://github.com/SecondFlight/anthem-engine.git",
            engine_repo_dir,
        ])
        .output()
        .unwrap();
    let clone_result_str = String::from_utf8_lossy(&clone_result.stderr);

    if clone_result_str.starts_with("fatal") {
        Command::new("git")
            .args(["-C", engine_repo_dir, "pull"])
            .status()
            .unwrap();
    }

    Command::new("cargo")
        .args([
            "+nightly",
            "build",
            "--manifest-path",
            engine_cargo_file,
            "--out-dir",
            engine_out_dir,
            "-Z",
            "unstable-options",
        ])
        .output()
        .unwrap();

    env::set_var("ANTHEM_ENGINE_DIR", engine_out_dir);
}
