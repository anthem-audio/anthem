$WorkingDirectory = Convert-Path .

if (-not(Test-Path ($WorkingDirectory + "\pubspec.yaml"))) {
    Write-Error "This script must be run from the project root."
    Exit
}

# This command should be run in the background during development. It keeps the
# *.g.dart files up-to-date as files are edited.

flutter pub run build_runner watch $args
