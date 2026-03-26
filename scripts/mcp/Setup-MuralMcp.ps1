#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#!
.SYNOPSIS
    Installs, builds, and authenticates the local Mural MCP server.

.DESCRIPTION
    Clones or updates the upstream mural-mcp repository into `.mcp/mural-mcp/`,
    builds it locally, loads credentials from `.mural-credentials`, and starts
    the interactive OAuth flow when tokens are missing, invalid, or expired.

.PARAMETER RepoRoot
    Optional. Repository root containing `.mural-credentials` and `.mcp/`.

.PARAMETER MuralRepoUrl
    Optional. Git repository URL for the upstream mural-mcp implementation.

.EXAMPLE
    ./scripts/mcp/Setup-MuralMcp.ps1

.EXAMPLE
    pwsh -File ./scripts/mcp/Setup-MuralMcp.ps1 -RepoRoot /path/to/repo
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,

    [Parameter(Mandatory = $false)]
    [string]$MuralRepoUrl = 'https://github.com/janschmiedgen/mural-mcp.git'
)

$ErrorActionPreference = 'Stop'

#region Module Import
Import-Module (Join-Path $PSScriptRoot 'Modules/MuralMcp.psm1') -Force
#endregion Module Import

#region Functions

function Invoke-MuralSetup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,

        [Parameter(Mandatory = $true)]
        [string]$UpstreamRepoUrl
    )

    foreach ($command in @('git', 'node', 'npm')) {
        if (-not (Test-CommandAvailable -CommandName $command)) {
            throw "Required command '$command' is not available on PATH."
        }
    }

    $mcpRoot = Join-Path $RepoRootPath '.mcp'
    $muralMcpPath = Join-Path $mcpRoot 'mural-mcp'
    $credentialsFile = Join-Path $RepoRootPath '.mural-credentials'
    $tokenFile = Join-Path $HOME '.mural-mcp/tokens.json'

    New-Item -ItemType Directory -Path $mcpRoot -Force | Out-Null
    Import-MuralCredentials -FilePath $credentialsFile -Force

    if (-not (Test-MuralCredentialsPresent)) {
        throw "Mural credentials are missing. Copy '.mural-credentials.example' to '.mural-credentials', fill in your Mural app credentials, then rerun this script."
    }

    Write-Host ''
    Write-Host '=== Mural MCP Setup ==='
    Write-Host ''

    if (-not (Test-Path -Path $muralMcpPath -PathType Container)) {
        Write-Host "Cloning mural-mcp into $muralMcpPath ..."
        & git clone $UpstreamRepoUrl $muralMcpPath
        if ($LASTEXITCODE -ne 0) {
            throw 'git clone failed.'
        }
    }
    else {
        Write-Host 'mural-mcp already exists locally. Pulling latest changes...'
        Push-Location $muralMcpPath
        try {
            & git pull --ff-only origin main
            if ($LASTEXITCODE -ne 0) {
                throw 'git pull failed.'
            }
        }
        finally {
            Pop-Location
        }
    }

    Push-Location $muralMcpPath
    try {
        Write-Host ''
        Write-Host 'Installing dependencies and building mural-mcp...'
        & npm install
        if ($LASTEXITCODE -ne 0) {
            throw 'npm install failed.'
        }

        & npm run build
        if ($LASTEXITCODE -ne 0) {
            throw 'npm run build failed.'
        }

        $tokenStatus = Get-MuralTokenStatus -TokenFile $tokenFile
        Write-Host ''
        switch ($tokenStatus) {
            'valid' {
                Write-Host "Existing valid Mural tokens found at $tokenFile. Skipping auth."
            }
            'expired' {
                Write-Host "Existing Mural tokens at $tokenFile are expired. Starting OAuth refresh..."
                & npm run auth
                if ($LASTEXITCODE -ne 0) {
                    throw 'npm run auth failed.'
                }
            }
            'invalid' {
                Write-Host "Existing Mural tokens at $tokenFile are invalid. Starting OAuth replacement..."
                & npm run auth
                if ($LASTEXITCODE -ne 0) {
                    throw 'npm run auth failed.'
                }
            }
            default {
                Write-Host 'No local Mural token file found. Starting OAuth setup...'
                & npm run auth
                if ($LASTEXITCODE -ne 0) {
                    throw 'npm run auth failed.'
                }
            }
        }
    }
    finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host '=== Mural MCP Ready ==='
    Write-Host ''
    Write-Host 'Add the Mural server entry to your workspace .vscode/mcp.json, then restart VS Code.'
    Write-Host "Use 'pwsh -File ./scripts/mcp/Start-MuralMcp.ps1' as the server command."
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-MuralSetup -RepoRootPath $RepoRoot -UpstreamRepoUrl $MuralRepoUrl
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Setup-MuralMcp.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution