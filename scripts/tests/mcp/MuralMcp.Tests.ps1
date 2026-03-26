#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Pester 5.x tests for the MuralMcp shared PowerShell module.
#>

BeforeAll {
    # Import the module under test
    $modulePath = Resolve-Path (Join-Path $PSScriptRoot '../../mcp/Modules/MuralMcp.psm1')
    Import-Module $modulePath -Force

    # Import mock helpers
    $mocksPath = Resolve-Path (Join-Path $PSScriptRoot '../Mocks/MuralMcpMocks.psm1')
    Import-Module $mocksPath -Force
}

# ---------------------------------------------------------------------------
# Import-MuralCredentials
# ---------------------------------------------------------------------------
Describe 'Import-MuralCredentials' {
    BeforeEach {
        Save-MuralEnvironment
        Clear-MuralEnvironment

        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "mural-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterEach {
        Restore-MuralEnvironment
        if (Test-Path $script:tempDir) {
            Remove-Item -Recurse -Force $script:tempDir
        }
    }

    It 'Sets both env vars from a well-formed credentials file' {
        $file = Join-Path $script:tempDir '.mural-credentials'
        @(
            'MURAL_CLIENT_ID=test-id-123'
            'MURAL_CLIENT_SECRET=test-secret-456'
        ) | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'test-id-123'
        $env:MURAL_CLIENT_SECRET | Should -Be 'test-secret-456'
    }

    It 'Strips double-quoted values' {
        $file = Join-Path $script:tempDir '.mural-credentials'
        @(
            'MURAL_CLIENT_ID="quoted-id"'
            'MURAL_CLIENT_SECRET="quoted-secret"'
        ) | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'quoted-id'
        $env:MURAL_CLIENT_SECRET | Should -Be 'quoted-secret'
    }

    It 'Strips single-quoted values' {
        $file = Join-Path $script:tempDir '.mural-credentials'
        @(
            "MURAL_CLIENT_ID='single-id'"
            "MURAL_CLIENT_SECRET='single-secret'"
        ) | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'single-id'
        $env:MURAL_CLIENT_SECRET | Should -Be 'single-secret'
    }

    It 'Handles export prefix' {
        $file = Join-Path $script:tempDir '.mural-credentials'
        @(
            'export MURAL_CLIENT_ID=export-id'
            'export MURAL_CLIENT_SECRET=export-secret'
        ) | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'export-id'
        $env:MURAL_CLIENT_SECRET | Should -Be 'export-secret'
    }

    It 'Skips blank lines and comments' {
        $file = Join-Path $script:tempDir '.mural-credentials'
        @(
            '# This is a comment'
            ''
            'MURAL_CLIENT_ID=comment-test'
            '  # Indented comment'
            'MURAL_CLIENT_SECRET=comment-secret'
        ) | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'comment-test'
        $env:MURAL_CLIENT_SECRET | Should -Be 'comment-secret'
    }

    It 'Returns silently when file does not exist' {
        { Import-MuralCredentials -FilePath '/nonexistent/path' } | Should -Not -Throw
        $env:MURAL_CLIENT_ID | Should -BeNullOrEmpty
    }

    It 'Does not overwrite existing env vars without -Force' {
        $env:MURAL_CLIENT_ID = 'existing-id'
        $file = Join-Path $script:tempDir '.mural-credentials'
        @('MURAL_CLIENT_ID=new-id') | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'existing-id'
    }

    It 'Overwrites existing env vars with -Force' {
        $env:MURAL_CLIENT_ID = 'existing-id'
        $file = Join-Path $script:tempDir '.mural-credentials'
        @('MURAL_CLIENT_ID=forced-id') | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file -Force
        $env:MURAL_CLIENT_ID | Should -Be 'forced-id'
    }

    It 'Ignores unrecognised variable names' {
        $file = Join-Path $script:tempDir '.mural-credentials'
        @(
            'OTHER_VAR=ignored'
            'MURAL_CLIENT_ID=only-id'
        ) | Set-Content -Path $file

        Import-MuralCredentials -FilePath $file
        $env:MURAL_CLIENT_ID | Should -Be 'only-id'
        $env:OTHER_VAR | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# Test-CommandAvailable
# ---------------------------------------------------------------------------
Describe 'Test-CommandAvailable' {
    It 'Returns $true for a known command' {
        Test-CommandAvailable -CommandName 'Get-ChildItem' | Should -BeTrue
    }

    It 'Returns $false for a non-existent command' {
        Test-CommandAvailable -CommandName 'NoSuchCommand-12345' | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# Test-MuralBuildExists
# ---------------------------------------------------------------------------
Describe 'Test-MuralBuildExists' {
    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "mural-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:tempDir) {
            Remove-Item -Recurse -Force $script:tempDir
        }
    }

    It 'Returns $true when the build file exists' {
        $buildFile = Join-Path $script:tempDir 'index.js'
        Set-Content -Path $buildFile -Value '// built'
        Test-MuralBuildExists -BuildPath $buildFile | Should -BeTrue
    }

    It 'Returns $false when the build file is missing' {
        Test-MuralBuildExists -BuildPath (Join-Path $script:tempDir 'missing.js') | Should -BeFalse
    }

    It 'Returns $false when the path is a directory' {
        $dir = Join-Path $script:tempDir 'subdir'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Test-MuralBuildExists -BuildPath $dir | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# Test-MuralCredentialsPresent
# ---------------------------------------------------------------------------
Describe 'Test-MuralCredentialsPresent' {
    BeforeEach {
        Save-MuralEnvironment
        Clear-MuralEnvironment
    }

    AfterEach {
        Restore-MuralEnvironment
    }

    It 'Returns $true when both vars are set' {
        $env:MURAL_CLIENT_ID = 'id'
        $env:MURAL_CLIENT_SECRET = 'secret'
        Test-MuralCredentialsPresent | Should -BeTrue
    }

    It 'Returns $false when MURAL_CLIENT_ID is missing' {
        $env:MURAL_CLIENT_SECRET = 'secret'
        Test-MuralCredentialsPresent | Should -BeFalse
    }

    It 'Returns $false when MURAL_CLIENT_SECRET is missing' {
        $env:MURAL_CLIENT_ID = 'id'
        Test-MuralCredentialsPresent | Should -BeFalse
    }

    It 'Returns $false when both are missing' {
        Test-MuralCredentialsPresent | Should -BeFalse
    }

    It 'Returns $false when vars are empty strings' {
        $env:MURAL_CLIENT_ID = ''
        $env:MURAL_CLIENT_SECRET = ''
        Test-MuralCredentialsPresent | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# Get-MuralTokenStatus
# ---------------------------------------------------------------------------
Describe 'Get-MuralTokenStatus' {
    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "mural-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:tempDir) {
            Remove-Item -Recurse -Force $script:tempDir
        }
    }

    It 'Returns "missing" when file does not exist' {
        Get-MuralTokenStatus -TokenFile (Join-Path $script:tempDir 'no-file.json') | Should -Be 'missing'
    }

    It 'Returns "invalid" when JSON is malformed' {
        $file = Join-Path $script:tempDir 'bad.json'
        Set-Content -Path $file -Value 'not json'
        Get-MuralTokenStatus -TokenFile $file | Should -Be 'invalid'
    }

    It 'Returns "invalid" when expires_at is zero' {
        $file = Join-Path $script:tempDir 'zero.json'
        @{ expires_at = 0 } | ConvertTo-Json | Set-Content -Path $file
        Get-MuralTokenStatus -TokenFile $file | Should -Be 'invalid'
    }

    It 'Returns "expired" when token is in the past' {
        $file = Join-Path $script:tempDir 'expired.json'
        $pastMs = [DateTimeOffset]::UtcNow.AddHours(-1).ToUnixTimeMilliseconds()
        @{ expires_at = $pastMs } | ConvertTo-Json | Set-Content -Path $file
        Get-MuralTokenStatus -TokenFile $file | Should -Be 'expired'
    }

    It 'Returns "expired" when token expires within 1 minute' {
        $file = Join-Path $script:tempDir 'soon.json'
        $soonMs = [DateTimeOffset]::UtcNow.AddSeconds(30).ToUnixTimeMilliseconds()
        @{ expires_at = $soonMs } | ConvertTo-Json | Set-Content -Path $file
        Get-MuralTokenStatus -TokenFile $file | Should -Be 'expired'
    }

    It 'Returns "valid" when token expires far in the future' {
        $file = Join-Path $script:tempDir 'valid.json'
        $futureMs = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeMilliseconds()
        @{ expires_at = $futureMs } | ConvertTo-Json | Set-Content -Path $file
        Get-MuralTokenStatus -TokenFile $file | Should -Be 'valid'
    }

    It 'Returns "invalid" when expires_at is negative' {
        $file = Join-Path $script:tempDir 'negative.json'
        @{ expires_at = -1 } | ConvertTo-Json | Set-Content -Path $file
        Get-MuralTokenStatus -TokenFile $file | Should -Be 'invalid'
    }
}

# ---------------------------------------------------------------------------
# Get-MuralPaths
# ---------------------------------------------------------------------------
Describe 'Get-MuralPaths' {
    It 'Returns a hashtable with all expected keys' {
        $result = Get-MuralPaths -RepoRoot '/tmp/repo'
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain 'McpRoot'
        $result.Keys | Should -Contain 'MuralMcpPath'
        $result.Keys | Should -Contain 'BuildPath'
        $result.Keys | Should -Contain 'CredentialsFile'
        $result.Keys | Should -Contain 'TokenFile'
    }

    It 'Builds paths relative to RepoRoot' {
        $result = Get-MuralPaths -RepoRoot '/tmp/repo'
        $result.McpRoot | Should -BeLike '*/.mcp'
        $result.MuralMcpPath | Should -BeLike '*/.mcp/mural-mcp'
        $result.BuildPath | Should -BeLike '*/.mcp/mural-mcp/build/index.js'
        $result.CredentialsFile | Should -BeLike '*/.mural-credentials'
    }

    It 'Uses HOME for TokenFile' {
        $result = Get-MuralPaths -RepoRoot '/tmp/repo'
        $result.TokenFile | Should -BeLike "$HOME*"
    }

    It 'Handles trailing-slash repo roots' {
        $result = Get-MuralPaths -RepoRoot '/tmp/repo/'
        $result.McpRoot | Should -Not -BeNullOrEmpty
    }

    It 'Accepts Windows-style paths' -Skip:(-not $IsWindows) {
        $result = Get-MuralPaths -RepoRoot 'C:\Users\test\repo'
        $result.BuildPath | Should -Not -BeNullOrEmpty
    }
}
