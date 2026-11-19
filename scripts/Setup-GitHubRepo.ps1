#requires -Version 5.1
<#
.SYNOPSIS
    Create the GitHub repository, push main, and configure main branch protection.

.DESCRIPTION
    Requires Git and an authenticated GitHub CLI (gh).
    The protection rule requires a pull request, one approval, and the
    "godot-import" status check.

    Private repositories need GitHub Pro/Team/Enterprise for branch protection.
    On GitHub Free, make the repository public or configure protection manually.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-GitHubRepo.ps1 -RepoName godot-game -Visibility private

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-GitHubRepo.ps1 -RepoName godot-game -SkipProtection
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$RepoName,

    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private',

    [string]$Owner = '',

    [switch]$SkipProtection
)

$ErrorActionPreference = 'Continue'

function Assert-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Assert-Command git
Assert-Command gh

& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated. Run: gh auth login'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot -ErrorAction Stop

try {
    if (-not (Test-Path (Join-Path $repoRoot '.git'))) {
        & git init -b main | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'git init failed'
        }
    }

    & git branch -M main | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not switch to the main branch'
    }

    & git rev-parse --verify HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & git add -A
        & git commit -m 'chore: bootstrap Godot 4 team repository' | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Initial commit failed. Check git user.name and git user.email.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($Owner)) {
        $Owner = (& gh api user --jq .login | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Owner)) {
            throw 'Could not determine the GitHub owner. Pass -Owner explicitly.'
        }
    }

    $fullName = "$Owner/$RepoName"
    $repoUrl = "https://github.com/$fullName.git"

    & gh repo view $fullName 2>$null | Out-Null
    $repoExists = ($LASTEXITCODE -eq 0)

    if (-not $repoExists) {
        Write-Host "Creating repository $fullName ($Visibility)..."
        & gh repo create $fullName "--$Visibility" --description 'Godot 4.x game - team repository'
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create $fullName"
        }
    }
    else {
        Write-Host "Repository $fullName already exists; reusing it."
    }

    & git remote get-url origin 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & git remote add origin $repoUrl
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to add the origin remote'
        }
    }
    else {
        $origin = (& git remote get-url origin | Out-String).Trim()
        if ($origin -notmatch [regex]::Escape($fullName)) {
            throw "origin already points to $origin (expected $repoUrl). Fix the remote first."
        }
    }

    Write-Host 'Pushing main...'
    & git push -u origin main
    if ($LASTEXITCODE -ne 0) {
        throw 'git push failed. If the remote already has commits, reconcile them first.'
    }

    & gh api --method PATCH "repos/$fullName" -f default_branch=main | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Could not set the default branch to main. Set it in Settings > Branches.'
    }

    if (-not $SkipProtection) {
        Write-Host 'Applying main branch protection...'

        $payload = [ordered]@{
            required_status_checks = [ordered]@{
                strict = $false
                contexts = @('godot-import')
            }
            enforce_admins = $false
            required_pull_request_reviews = [ordered]@{
                dismiss_stale_reviews = $true
                require_code_owner_reviews = $false
                required_approving_review_count = 1
                require_last_push_approval = $false
            }
            restrictions = $null
            required_conversation_resolution = $true
            allow_force_pushes = $false
            allow_deletions = $false
            block_creations = $false
            required_linear_history = $false
            lock_branch = $false
            allow_fork_syncing = $false
        }

        $json = $payload | ConvertTo-Json -Depth 10
        $tempFile = [System.IO.Path]::GetTempFileName()

        try {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($tempFile, $json, $utf8NoBom)

            & gh api --method PUT "repos/$fullName/branches/main/protection" --input $tempFile | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw 'Branch protection failed. Private repositories need GitHub Pro/Team/Enterprise. Make the repository public, upgrade the plan, or configure Settings > Branches manually.'
            }
        }
        finally {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Done: main requires a PR, 1 approval, and the 'godot-import' check."
    }

    Write-Host "Repository: https://github.com/$fullName"
    Write-Host "Actions:    https://github.com/$fullName/actions"
}
finally {
    Pop-Location
}
