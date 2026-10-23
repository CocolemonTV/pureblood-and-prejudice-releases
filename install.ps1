# Windows PowerShell 5.1+. Run in a normal, non-administrator PowerShell window.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $repository = 'https://github.com/CocolemonTV/pureblood-and-prejudice-releases'
    # electron-builder's UUID v5 for appId dev.ruizukun.purebloodandprejudice.
    $appGuid = '9274648a-6ffb-527f-b1f2-4bff1426cfc1'
    $tempDirectory = $null

    function Get-PPInstallation {
        # Read both registry views, including installs made from a 32-bit shell.
        foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryHive]::LocalMachine)) {
            foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
                $root = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
                $key = $null
                $locationKey = $null
                try {
                    $key = $root.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Uninstall\$appGuid")
                    if ($null -ne $key) {
                        $locationKey = $root.OpenSubKey("Software\$appGuid")
                        $location = $null
                        if ($null -ne $locationKey) { $location = $locationKey.GetValue('InstallLocation') }
                        return [pscustomobject]@{
                            Version = [string]$key.GetValue('DisplayVersion')
                            Uninstall = [string]$key.GetValue('UninstallString')
                            Location = [string]$location
                            AllUsers = ($hive -eq [Microsoft.Win32.RegistryHive]::LocalMachine)
                        }
                    }
                }
                finally {
                    if ($null -ne $locationKey) { $locationKey.Dispose() }
                    if ($null -ne $key) { $key.Dispose() }
                    $root.Dispose()
                }
            }
        }
        return $null
    }

    try {
        if ($env:OS -ne 'Windows_NT') { throw 'This installer supports Windows only.' }
        $architecture = $env:PROCESSOR_ARCHITECTURE
        if ($env:PROCESSOR_ARCHITEW6432) { $architecture = $env:PROCESSOR_ARCHITEW6432 }
        if ($architecture -ne 'AMD64') { throw "Unsupported architecture: $architecture. Use 64-bit Windows on an x86-64 computer." }
        $saves = Join-Path $env:APPDATA 'Pureblood-and-Prejudice'
        $installed = Get-PPInstallation
        if ($null -ne $installed -and $installed.AllUsers) {
            throw 'An all-users installation exists. Manage it through Windows Settings, then run this command as your normal user.'
        }

        if ($env:PP_UNINSTALL -eq '1') {
            if ($null -eq $installed) {
                Write-Output "Already uninstalled. Saves kept at $saves"
                return
            }
            # Use only the executable from the registry, never evaluate its command.
            $match = [regex]::Match($installed.Uninstall, '^\s*"([^"]+\.exe)"(?:\s|$)', 'IgnoreCase')
            if (-not $match.Success) { throw 'Could not find the uninstaller. Remove the game through Windows Settings.' }
            $uninstaller = $match.Groups[1].Value
            if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) { throw 'The uninstaller is missing. Remove the game through Windows Settings.' }
            Write-Output 'Uninstalling Pureblood & Prejudice...'
            $process = Start-Process -FilePath $uninstaller -ArgumentList @('/S', '/currentuser') -WindowStyle Hidden -Wait -PassThru
            if ($process.ExitCode -ne 0) { throw "The uninstaller returned exit code $($process.ExitCode)." }
            # NSIS may finish through a temporary child process.
            $deadline = [DateTime]::UtcNow.AddSeconds(60)
            while ($null -ne (Get-PPInstallation) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 500
            }
            if ($null -ne (Get-PPInstallation)) { throw 'Uninstall did not finish. Try removing the game through Windows Settings.' }
            Write-Output "Uninstalled. Saves kept at $saves"
            return
        }

        $version = $env:PP_VERSION
        if ([string]::IsNullOrEmpty($version)) {
            # Follow the public redirect. No GitHub API or token is required.
            $request = [Net.HttpWebRequest]::Create("$repository/releases/latest")
            $request.Method = 'HEAD'
            $request.AllowAutoRedirect = $true
            $request.UserAgent = 'Pureblood-and-Prejudice-installer'
            $request.Timeout = 60000
            $response = $request.GetResponse()
            try { $latest = $response.ResponseUri.AbsoluteUri }
            finally { $response.Dispose() }
            $prefix = "$repository/releases/tag/v"
            if (-not $latest.StartsWith($prefix, [StringComparison]::Ordinal)) { throw 'GitHub did not redirect to a release. Please try again.' }
            $version = $latest.Substring($prefix.Length)
        }
        if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'PP_VERSION must look like 0.3.1 (without v).' }
        if ($null -ne $installed -and $installed.Version -eq $version) {
            Write-Output "Pureblood & Prejudice $version is already up to date."
            return
        }

        $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ('pp-install-' + [Guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempDirectory
        $asset = "Pureblood-and-Prejudice-$version-win-x64.exe"
        $base = "$repository/releases/download/v$version"
        $checksums = Join-Path $tempDirectory 'SHA256SUMS.txt'
        $installer = Join-Path $tempDirectory $asset
        Write-Output "Downloading Pureblood & Prejudice $version..."
        Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS.txt" -OutFile $checksums
        $pattern = '^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($asset) + '$'
        $checksumMatches = @(Get-Content -LiteralPath $checksums | ForEach-Object {
            $entry = [regex]::Match($_, $pattern)
            if ($entry.Success) { $entry.Groups[1].Value }
        })
        if ($checksumMatches.Count -ne 1) { throw "No unique SHA-256 checksum found for $asset." }
        Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile $installer
        if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $checksumMatches[0]) {
            throw 'SHA-256 mismatch. Nothing was installed. Please try again.'
        }
        # NSIS is assisted, per-user, with a configurable install directory.
        # /currentuser keeps upgrades in the existing per-user directory.
        # /S does not launch the app. Do not alter Defender or SmartScreen settings.
        $process = Start-Process -FilePath $installer -ArgumentList @('/S', '/currentuser') -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "The installer returned exit code $($process.ExitCode)." }
        $result = Get-PPInstallation
        if ($null -eq $result -or $result.Version -ne $version) { throw 'Could not confirm the installed version. Check Windows Settings.' }
        Write-Output "Installed $($result.Version). Open Pureblood & Prejudice from the Start menu."
        Write-Output 'Run the same command again to update. Saves are kept.'
    }
    finally {
        if ($null -ne $tempDirectory -and (Test-Path -LiteralPath $tempDirectory)) {
            Remove-Item -LiteralPath $tempDirectory -Recurse -Force
        }
    }
}
