$WorkingDirectory = Convert-Path .

if (-not(Test-Path ($WorkingDirectory + "\pubspec.yaml"))) {
    Write-Error "This script must be run from the project root."
    Exit
}

# https://github.com/fzyzcjy/flutter_rust_bridge/issues/249
# There's an awful workaround here. As of writing flutter_rust_bridge does not
# support codegen for dependencies, so we can't serialize the shared model
# library. However, these dependencies are only shared to make IPC easier, so
# we can just copy-paste the dependencies into the same crate before running 
# codegen. Again this is profoundly bad and I am painfully aware, but it will
# do for now.

# Delete everything except mod.rs
Get-ChildItem "rust\src\dependencies\engine_model" -Exclude mod.rs | Remove-Item -Recurse

Copy-Item `
    -Path "rust\engine_model\src\*" `
    -Destination "rust\src\dependencies\engine_model" `
    -Recurse `
    -Force

Remove-Item `
    -Path "rust\src\dependencies\engine_model\lib.rs"

# Main API
flutter_rust_bridge_codegen `
    --rust-input rust\src\api.rs `
    --dart-output lib\generated\api.dart `
    --rust-output rust\src\generated\api.rs
    # iOS is probably broken anyway
    # --c-output ios\Runner\flutter_rust_bridge_generated.h
