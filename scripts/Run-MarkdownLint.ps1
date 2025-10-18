<#!
.SYNOPSIS
    Runs markdownlint across all markdown files in the repository.

.DESCRIPTION
    Convenience script to enforce strict markdownlint rules locally.
    Requires markdownlint-cli installed (npm i -g markdownlint-cli) or via npx.

.PARAMETER UseNpx
    If set, runs markdownlint via npx without requiring global install.

.EXAMPLE
    .\scripts\Run-MarkdownLint.ps1

.EXAMPLE
    .\scripts\Run-MarkdownLint.ps1 -UseNpx
#>
param(
    [switch]$UseNpx
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

 $configPath = Join-Path $PSScriptRoot '..' '.markdownlint.json'
 $ignorePath = Join-Path $PSScriptRoot '..' '.markdownlintignore'
 $mdGlob = '**/*.md'

 if (-not (Test-Path $configPath)) {
     Write-Warning "Config file not found: $configPath"
 }

 $runner = 'markdownlint'
 if ($UseNpx) { $runner = 'npx markdownlint' }
 else {
     if (-not (Get-Command markdownlint -ErrorAction SilentlyContinue)) {
         Write-Host 'Global markdownlint not found, falling back to npx.' -ForegroundColor Yellow
         $runner = 'npx markdownlint'
     }
 }

 $command = "$runner \"$mdGlob\" -c \"$configPath\" -i \"$ignorePath\""
 Write-Host "Running: $command" -ForegroundColor Cyan
 try {
     iex $command
     Write-Host 'Markdownlint completed.' -ForegroundColor Green
 }
 catch {
     Write-Error "Markdownlint failed: $_"
     exit 1
 }
