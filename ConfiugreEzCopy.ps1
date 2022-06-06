param(
    [switch]$Install = $false,
    [switch]$Update = $false,
    [switch]$Uninstall = $false,
    [switch]$Configure = $false
)
$ErrorActionPreference = "Stop"
$global:Entries = @()
# $global:Entries = @(
#     @{BlobPath = ""; SasToken = "" }
#     @{BlobPath = ""; SasToken = "" }
# )

function Get-OSArchitecture {
    if (Get-Command "Get-CimInstance" -ErrorAction SilentlyContinue) {
        return (Get-CimInstance -ClassName win32_operatingsystem).OSArchitecture
    }
    else {
        return (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    }
}

$OSArchitecture = Get-OSArchitecture
$EzCopyDirectory = $env:LOCALAPPDATA + "\EzCopy\"
$EzCopyDownloadPath = "https://raw.githubusercontent.com/js1016/EzCopy/main/EzCopy.ps1"
$EzCopyDownloadPath2 = "http://joji.blob.core.windows.net/ezcopy/EzCopy.ps1"
$EzCopySavePath = $EzCopyDirectory + "EzCopy.ps1"
$AzCopyDownloadPath = "https://aka.ms/downloadazcopy-v10-windows-32bit"
$AzCopyDownloadPath2 = "http://joji.blob.core.windows.net/ezcopy/azcopy_windows_386_10.15.0.zip"
$AzCopySavePath = $EzCopyDirectory + "AzCopy.zip"
if ($OSArchitecture.StartsWith("64")) {
    $AzCopyDownloadPath = "https://aka.ms/downloadazcopy-v10-windows"
    $AzCopyDownloadPath2 = "http://joji.blob.core.windows.net/ezcopy/azcopy_windows_amd64_10.15.0.zip"
}
$PSCommand = "powershell.exe"
if ($PSVersionTable.PSEdition -eq "Core") {
    $PSCommand = "pwsh.exe"
}
$PSCommand = "$($PSHOME)\$($PSCommand)"

function Get-RemoteResource {
    param(
        [string]$Url,
        [string]$SavePath,
        [string]$Url2
    )
    $UseBitsTransfer = $true
    if (Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue) {
        Start-BitsTransfer $Url $SavePath -ErrorAction SilentlyContinue
    }
    else {
        $UseBitsTransfer = $false
    }
    if (!(Test-Path $SavePath) -or !$UseBitsTransfer) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $wc = New-Object Net.WebClient
            $wc.DownloadFile($Url, $SavePath)
        }
        catch {}
    }
    if (!(Test-Path $SavePath)) {
        $wc = New-Object Net.WebClient
        $wc.DownloadFile($Url2, $SavePath)
    }
}

function Expand-ArchiveEx {
    param(
        [string]$Path,
        [string]$DestinationPath
    )
    if (Get-Command "Expand-Archive" -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $Path -DestinationPath $DestinationPath
    }
    else {
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($Path)
        foreach ($item in $zip.items()) {
            $shell.Namespace($DestinationPath).copyhere($item)
        }
    }
}

function Get-AzCopy {
    Write-Host "Downloading AzCopy.exe to $($EzCopyDirectory)"
    Get-RemoteResource -Url $AzCopyDownloadPath -SavePath $AzCopySavePath -Url2 $AzCopyDownloadPath2
    Expand-ArchiveEx -Path $AzCopySavePath -DestinationPath $EzCopyDirectory -Force
    $findResult = Get-ChildItem -Path $EzCopyDirectory -Filter "azcopy.exe" -Recurse
    if ($findResult) {
        $target = $null
        if ($findResult -is [array]) {
            foreach ($match in $findResult) {
                if (!$target -and $match.Directory.Name.ToLower() -ne "ezcopy") {
                    $target = $match
                }
                elseif ($match.LastWriteTime -gt $target.LastWriteTime -and $match.Directory.Name.ToLower() -ne "ezcopy") {
                    $target = $match
                }
            }
        }
        else {
            if ($findResult.Directory.Name.ToLower() -ne "ezcopy") {
                $target = $findResult
            }
        }
        if ($target) {
            Move-Item -Path $target.FullName -Destination $EzCopyDirectory -Force
            Remove-Item -Path $target.DirectoryName -Recurse
        }
    }
    else {
        Remove-Item -Path $AzCopySavePath
        throw "Did not find azcopy.exe after extraction"
    }
    Remove-Item -Path $AzCopySavePath
}

function Get-EzCopy {
    Write-Host "Downloading EzCopy to $($EzCopyDirectory)"
    Get-RemoteResource -Url $EzCopyDownloadPath -SavePath $EzCopySavePath -Url2 $EzCopyDownloadPath2
}

function Uninstall-EzCopy {
    Remove-Item -LiteralPath $EzCopyDirectory -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -LiteralPath "HKCU:\SOFTWARE\Classes\*\shell\EzCopy" -Force -Recurse
}

function Update-EzCopy {
    if (Test-Path $EzCopyDirectory) {
        Write-Host "Updating EzCopy..."
        Get-AzCopy
        Get-EzCopy
    }
    else {
        throw "EzCopy is not installed, please install it first."
    }
}

function Install-EzCopy { 
    Write-Host "Installing EzCopy..."
    New-Item -Path $env:LOCALAPPDATA -Name "EzCopy" -ItemType "Directory" -Force | Out-Null
    Get-AzCopy
    Get-EzCopy
    Set-EzCopy
}

function Set-EzCopy {
    if ($global:Entries.Count -eq 0) {
        $firstOrSecondOrThird = "first"
        $continue = $true
        Write-Host "You can configure up to three different containers or paths as upload entries in context menu."
        while ($continue) {
            $blobPathUri = [uri](Read-Host -Prompt "Let's configure the $($firstOrSecondOrThird) upload entry, please input the default upload path (example: https://contoso.blob.core.windows.net/container/optionalpath/)")
            $blobPath = ""
            $testBlobPathResult = Test-BlobPath($blobPathUri)
            while ($testBlobPathResult.Length) {
                Write-Host "Invalid upload path: $($testBlobPathResult)" -ForegroundColor Red
                $blobPathUri = [uri](Read-Host -Prompt "Please input the default upload path")
                $testBlobPathResult = Test-BlobPath($blobPathUri)
            }
            if ($blobPathUri.Query.Length) {
                $blobPath = $blobPathUri.AbsoluteUri.Replace($blobPathUri.Query, "")
            }
            else {
                $blobPath = $blobPathUri.AbsoluteUri.Replace($blobPathUri.AbsoluteUri.Substring($blobPathUri.AbsoluteUri.IndexOf("/", 8)), $blobPathUri.AbsolutePath)
            }
            if (!$blobPath.EndsWith("/")) {
                $blobPath = $blobPath += "/"
            }
            $sasToken = Read-Host -Prompt "Please input the SAS token for the URL: $($blobPath)"
            $global:Entries += @{BlobPath = $blobPath; SasToken = $sasToken }
            if ($global:Entries.Count -lt 3) {
                $continueInput = Read-Host -Prompt "Do you want to configure another upload entry? Please input (Y) or (N)"
                if ($continueInput.ToLower() -eq "y") {
                    $continue = $true
                    if ($global:Entries.Count -eq 1) {
                        $firstOrSecondOrThird = "second"
                    }
                    elseif ($global:Entries.Count -eq 2) {
                        $firstOrSecondOrThird = "third"
                    }
                }
                else {
                    $continue = $false
                }
            }
            else {
                $continue = $false
            }
        }
    }
    Remove-Item -LiteralPath "HKCU:\SOFTWARE\Classes\*\shell\EzCopy" -Force -Recurse -ErrorAction SilentlyContinue
    New-Item "HKCU:\SOFTWARE\Classes\*\shell\EzCopy\" -Force | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\SOFTWARE\Classes\*\shell\EzCopy" -Name "subcommands" -Value "" -Force | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\SOFTWARE\Classes\*\shell\EzCopy" -Name "MUIVerb" -Value "EzCopy" -Force | Out-Null
    $sasFileContent = ""
    for ($i = 0; $i -lt $global:Entries.Count -and $i -lt 3; $i++) {
        $entry = $global:Entries[$i]
        $entryRegPath = "HKCU:\SOFTWARE\Classes\*\shell\EzCopy\shell\blob$($i+1)\"
        New-Item "$($entryRegPath)shell\1\command" -Force | Out-Null
        New-Item "$($entryRegPath)shell\2\command" -Force | Out-Null
        New-Item "$($entryRegPath)shell\3\command" -Force | Out-Null
        New-Item "$($entryRegPath)shell\4\command" -Force | Out-Null
        New-ItemProperty -LiteralPath $entryRegPath -Name "subcommands" -Value "" -Force | Out-Null
        New-ItemProperty -LiteralPath $entryRegPath -Name "MUIVerb" -Value "Upload to $($entry.BlobPath)" -Force | Out-Null
        New-ItemProperty -LiteralPath "$($entryRegPath)shell\1\" -Name "MUIVerb" -Value "Keep original file name" -Force | Out-Null
        New-ItemProperty -LiteralPath "$($entryRegPath)shell\2\" -Name "MUIVerb" -Value "Use MD5 hash as file name" -Force | Out-Null
        New-ItemProperty -LiteralPath "$($entryRegPath)shell\3\" -Name "MUIVerb" -Value "Use SHA256 hash as file name" -Force | Out-Null
        New-ItemProperty -LiteralPath "$($entryRegPath)shell\4\" -Name "MUIVerb" -Value "Customize path and file name" -Force | Out-Null
        Set-ItemProperty -LiteralPath "$($entryRegPath)shell\1\command" -Name "(Default)" -Type "ExpandString" -Value "$($PSCommand) -File %localappdata%\\EzCopy\\EzCopy.ps1 -FilePath ""%1"" -BlobPath ""$($entry.BlobPath)"""
        Set-ItemProperty -LiteralPath "$($entryRegPath)shell\2\command" -Name "(Default)" -Type "ExpandString" -Value "$($PSCommand) -File %localappdata%\\EzCopy\\EzCopy.ps1 -FilePath ""%1"" -BlobPath ""$($entry.BlobPath)"" -FileHash md5"
        Set-ItemProperty -LiteralPath "$($entryRegPath)shell\3\command" -Name "(Default)" -Type "ExpandString" -Value "$($PSCommand) -File %localappdata%\\EzCopy\\EzCopy.ps1 -FilePath ""%1"" -BlobPath ""$($entry.BlobPath)"" -FileHash sha256"
        Set-ItemProperty -LiteralPath "$($entryRegPath)shell\4\command" -Name "(Default)" -Type "ExpandString" -Value "$($PSCommand) -File %localappdata%\\EzCopy\\EzCopy.ps1 -FilePath ""%1"" -BlobPath ""$($entry.BlobPath)"" -Custom"
        $sasFileContent += "$($entry.BlobPath) $($entry.SasToken | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString)`n"
    }
    New-Item -Path $EzCopyDirectory"sas.txt" -ItemType "File" -Value $sasFileContent -Force | Out-Null
}

function Test-BlobPath {
    param(
        [uri] $blobPath
    )
    $testBlobPathResult = ""
    if ($blobPath.LocalPath.Length -lt 2) {
        $testBlobPathResult = "The upload path could not be your root blob URL, you need to specify the container in the path like: https://contoso.blob.core.windows.net/container/"
    }
    elseif (!$blobPath.Scheme.StartsWith("http")) {
        $testBlobPathResult = "The blob path should start with 'http'."
    }
    return $testBlobPathResult
}

if ($Install) {
    try {
        Install-EzCopy
        Write-Host "EzCopy is installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Installing EzCopy failed with error: $($_)" -ForegroundColor Red
        Write-Host "ScriptStackTrace: `n$($_.ScriptStackTrace)" -ForegroundColor Red
    }
}
elseif ($Update) {
    try {
        Update-EzCopy
        Write-Host "EzCopy is updated successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Updating EzCopy failed with error: $($_)" -ForegroundColor Red
        Write-Host "ScriptStackTrace: `n$($_.ScriptStackTrace)" -ForegroundColor Red
    }
}
elseif ($Uninstall) {
    Uninstall-EzCopy
    Write-Host "EzCopy is removed successfully!" -ForegroundColor Green
}
elseif ($Configure) {
    $global:Entries = @()
    Set-EzCopy
    Write-Host "EzCopy is configured successfully!" -ForegroundColor Green
}