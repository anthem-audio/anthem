$WorkingDirectory = Convert-Path .

if (-not(Test-Path ($WorkingDirectory + "\pubspec.yaml"))) {
    Write-Error "This script must be run from the project root."
    Exit
}

flutter_rust_bridge_codegen `
    --rust-input rust\\src\\api.rs `
    --dart-output lib\\flutter_rust_bridge_generated.dart `
    --c-output ios\\Runner\\bridge_generated.h `
    --rust-output rust\\src\\flutter_rust_bridge_generated.rs
