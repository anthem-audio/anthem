$WorkingDirectory = Convert-Path .

if (-not(Test-Path ($WorkingDirectory + "\pubspec.yaml"))) {
    Write-Error "This script must be run from the project root."
    Exit
}

Get-ChildItem -Path .\assets\icons -Recurse |
    % {
        if ($_.Name -cne $_.Name.ToLower().Replace("-", "_").Replace(" ", "_") ) {
            # https://til.secretgeek.net/powershell/Rename_to_lower_case.html
            $NewName = $_.Name.ToLower().Replace("-", "_").Replace(" ", "_")

            $TempItem = Rename-Item -Path $_.FullName -NewName "x$NewName" -PassThru

            Rename-Item -Path $TempItem.FullName -NewName $NewName
        }
    }
