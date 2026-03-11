$claudeDir = "$env:USERPROFILE\.claude"

# Create directories if missing
$dirs = @(
    $claudeDir,
    "$claudeDir\commands",
    "$claudeDir\agents"
)
foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir"
    }
}

# Create files if missing
$files = @(
    "$env:USERPROFILE\.claude.json",
    "$claudeDir\.credentials.json",
    "$claudeDir\settings.json",
    "$claudeDir\CLAUDE.md"
)
foreach ($file in $files) {
    if (!(Test-Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
        Write-Host "Created file: $file"
    }
}

Write-Host "Done. You can now run docker-compose up."
