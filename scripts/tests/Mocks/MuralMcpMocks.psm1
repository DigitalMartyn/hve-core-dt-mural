# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# MuralMcpMocks.psm1
#
# Purpose: Reusable mock helpers for Mural MCP Pester tests.
# Author: HVE Core Team
#

#region Environment State Management

function Save-MuralEnvironment {
    <#
    .SYNOPSIS
    Saves current Mural environment variables for later restoration.
    #>
    [CmdletBinding()]
    param()

    $script:SavedMuralEnv = @{
        MURAL_CLIENT_ID     = $env:MURAL_CLIENT_ID
        MURAL_CLIENT_SECRET = $env:MURAL_CLIENT_SECRET
    }

    Write-Verbose 'Saved Mural environment state'
}

function Restore-MuralEnvironment {
    <#
    .SYNOPSIS
    Restores Mural environment variables to saved state.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:SavedMuralEnv) {
        Write-Warning 'No saved Mural environment state found'
        return
    }

    foreach ($key in $script:SavedMuralEnv.Keys) {
        if ($null -eq $script:SavedMuralEnv[$key]) {
            Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path "env:$key" -Value $script:SavedMuralEnv[$key]
        }
    }

    Write-Verbose 'Restored Mural environment state'
}

function Clear-MuralEnvironment {
    <#
    .SYNOPSIS
    Removes MURAL_CLIENT_ID and MURAL_CLIENT_SECRET from the environment.
    #>
    [CmdletBinding()]
    param()

    Remove-Item -Path 'env:MURAL_CLIENT_ID' -ErrorAction SilentlyContinue
    Remove-Item -Path 'env:MURAL_CLIENT_SECRET' -ErrorAction SilentlyContinue

    Write-Verbose 'Cleared Mural environment variables'
}

#endregion Environment State Management

Export-ModuleMember -Function @(
    'Save-MuralEnvironment'
    'Restore-MuralEnvironment'
    'Clear-MuralEnvironment'
)
