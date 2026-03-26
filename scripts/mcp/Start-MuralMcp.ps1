#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#!
.SYNOPSIS
    Starts the local Mural MCP server for workspace use.

.DESCRIPTION
    Loads Mural OAuth credentials from environment variables or a local
    `.mural-credentials` file, then launches the built mural-mcp server from
    `.mcp/mural-mcp/build/index.js` using stdio transport for VS Code MCP.

.PARAMETER RepoRoot
    Optional. Repository root containing `.mural-credentials` and `.mcp/`.

.EXAMPLE
    ./scripts/mcp/Start-MuralMcp.ps1

.EXAMPLE
    pwsh -File ./scripts/mcp/Start-MuralMcp.ps1 -RepoRoot /path/to/repo
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'

#region Module Import
Import-Module (Join-Path $PSScriptRoot 'Modules/MuralMcp.psm1') -Force
#endregion Module Import

#region Functions

function Invoke-StartMuralMcp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    $credentialsFile = Join-Path $RepoRootPath '.mural-credentials'
    $buildPath = Join-Path $RepoRootPath '.mcp/mural-mcp/build/index.js'

    Import-MuralCredentials -FilePath $credentialsFile

    if (-not (Test-MuralBuildExists -BuildPath $buildPath)) {
        throw "Mural MCP is not installed at '$buildPath'. Run 'npm run mcp:setup:mural' first."
    }

    if (-not (Test-MuralCredentialsPresent)) {
        throw "Mural credentials are missing. Create '.mural-credentials' from '.mural-credentials.example' or set MURAL_CLIENT_ID and MURAL_CLIENT_SECRET in your environment."
    }

    & node $buildPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        exit $exitCode
    }
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-StartMuralMcp -RepoRootPath $RepoRoot
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Start-MuralMcp.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution