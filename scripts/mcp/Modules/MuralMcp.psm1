# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# MuralMcp.psm1
#
# Purpose: Shared helpers for the Mural MCP setup and start scripts.
# Author: HVE Core Team
#

function Import-MuralCredentials {
    <#
    .SYNOPSIS
    Loads MURAL_CLIENT_ID and MURAL_CLIENT_SECRET from a dotenv-style file.

    .PARAMETER FilePath
    Path to the credentials file.

    .PARAMETER Force
    When set, overwrites existing environment variables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [switch]$Force
    )

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        return
    }

    foreach ($line in Get-Content -Path $FilePath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^(?:export\s+)?(?<name>MURAL_CLIENT_ID|MURAL_CLIENT_SECRET)=(?<value>.+)$') {
            $name = $Matches.name
            $value = $Matches.value.Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            $existing = (Get-Item -Path Env:$name -ErrorAction SilentlyContinue).Value
            if ($Force -or [string]::IsNullOrWhiteSpace($existing)) {
                Set-Item -Path Env:$name -Value $value
            }
        }
    }
}

function Test-CommandAvailable {
    <#
    .SYNOPSIS
    Returns $true when the given command is on PATH.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Test-MuralBuildExists {
    <#
    .SYNOPSIS
    Returns $true when the built mural-mcp index.js exists.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildPath
    )

    return (Test-Path -Path $BuildPath -PathType Leaf)
}

function Test-MuralCredentialsPresent {
    <#
    .SYNOPSIS
    Returns $true when both MURAL_CLIENT_ID and MURAL_CLIENT_SECRET are set.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return (-not [string]::IsNullOrWhiteSpace($env:MURAL_CLIENT_ID) -and
            -not [string]::IsNullOrWhiteSpace($env:MURAL_CLIENT_SECRET))
}

function Get-MuralTokenStatus {
    <#
    .SYNOPSIS
    Returns the status of the local Mural OAuth token file.

    .OUTPUTS
    One of: 'valid', 'expired', 'invalid', 'missing'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TokenFile
    )

    if (-not (Test-Path -Path $TokenFile -PathType Leaf)) {
        return 'missing'
    }

    try {
        $tokenData = Get-Content -Path $TokenFile -Raw | ConvertFrom-Json
        $expiresAt = [double]$tokenData.expires_at
        if ($expiresAt -le 0) {
            return 'invalid'
        }

        $expiry = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$expiresAt)
        if ($expiry -le [DateTimeOffset]::UtcNow.AddMinutes(1)) {
            return 'expired'
        }

        return 'valid'
    }
    catch {
        return 'invalid'
    }
}

function Get-MuralPaths {
    <#
    .SYNOPSIS
    Returns a hashtable of standard Mural MCP paths relative to the repo root.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    return @{
        McpRoot         = Join-Path $RepoRoot '.mcp'
        MuralMcpPath    = Join-Path $RepoRoot '.mcp/mural-mcp'
        BuildPath       = Join-Path $RepoRoot '.mcp/mural-mcp/build/index.js'
        CredentialsFile = Join-Path $RepoRoot '.mural-credentials'
        TokenFile       = Join-Path $HOME '.mural-mcp/tokens.json'
    }
}

Export-ModuleMember -Function @(
    'Import-MuralCredentials'
    'Test-CommandAvailable'
    'Test-MuralBuildExists'
    'Test-MuralCredentialsPresent'
    'Get-MuralTokenStatus'
    'Get-MuralPaths'
)
