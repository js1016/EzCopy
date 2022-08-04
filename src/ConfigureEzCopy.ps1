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
$EzCopyDownloadPath = "https://joji.blob.core.windows.net/ezcopy"
$EzCopyDownloadPath2 = "http://joji.blob.core.windows.net/ezcopy"
$AzCopyDownloadPath = "https://aka.ms/downloadazcopy-v10-windows-32bit"
$AzCopyDownloadPath2 = "http://joji.blob.core.windows.net/ezcopy/azcopy_windows_386_10.16.0.zip"
$AzCopySavePath = $EzCopyDirectory + "AzCopy.zip"
if ($OSArchitecture.StartsWith("64")) {
    $AzCopyDownloadPath = "https://aka.ms/downloadazcopy-v10-windows"
    $AzCopyDownloadPath2 = "http://joji.blob.core.windows.net/ezcopy/azcopy_windows_amd64_10.16.0.zip"
}
$PSCommand = "powershell.exe"
if ($PSVersionTable.PSEdition -eq "Core") {
    $PSCommand = "pwsh.exe"
}
$PSCommand = "$($PSHOME)\$($PSCommand)"
$PreConfigured = if ($global:Entries.Length -gt 0) { $true }else { $false }
$CommandLineArgs = [System.Environment]::GetCommandLineArgs()
$SciprtExecuteViaFile = $false
for ($i = 0; $i -lt $CommandLineArgs.Length; $i++) {
    if ($CommandLineArgs[$i].ToLower() -eq "-file") {
        $SciprtExecuteViaFile = $true
        break
    }
}
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
        catch {
        }
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
    Get-RemoteResource -Url ($EzCopyDownloadPath + "/EzCopy.ps1") -SavePath ($EzCopyDirectory + "EzCopy.ps1") -Url2 ($EzCopyDownloadPath2 + "/EzCopy.ps1")
    Get-RemoteResource -Url ($EzCopyDownloadPath + "/ConfigureEzCopy.ps1") -SavePath ($EzCopyDirectory + "ConfigureEzCopy.ps1") -Url2 ($EzCopyDownloadPath2 + "/ConfigureEzCopy.ps1")
}

function Uninstall-EzCopy {
    Remove-Item -LiteralPath $EzCopyDirectory -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -LiteralPath "HKCU:\SOFTWARE\Classes\*\shell\EzCopy" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
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

function Write-Description {
    param(
        [string]$Description
    )
    Write-Host "`nDescription:        " -NoNewline
    $wroteFirstLine = $false
    $lines = $Description.Split("`n")
    foreach ($line in $lines) {
        if ($wroteFirstLine) {
            Write-Host "`n                    " -NoNewline
        }
        else {
            $wroteFirstLine = $true
        }
        if ($line.Length -gt 50) {
            $words = $line.Split(' ')
            $outputLength = 0;
            $i = 0;
            while ($outputLength -le 50 -and $i -lt $words.Length) {
                Write-Host ($words[$i] + " ") -NoNewline
                $outputLength += $words[$i].Length + 1
                $i++
                if ($outputLength -ge 50 -and $i -lt $words.Length) {
                    Write-Host "`n                    " -NoNewline
                    $outputLength = 0;
                }
            }
        }
        else {
            Write-Host $line -NoNewline
        }
    }
    Write-Host "`n"
}

function Set-EzCopy {
    if ($global:Entries.Count -eq 0) {
        $firstOrSecondOrThird = "first"
        $continue = $true
        Write-Host "`nYou can configure up to three different upload paths in context menu."
        while ($continue) {
            Write-Host "`nLet's configure the $($firstOrSecondOrThird) upload entry, please input the upload path." -ForegroundColor Green
            Write-Description "This will be the default upload path. You must specify the container or file share of your blob service and you can also specify an optional path of your container or file share.`n`nExamples:`n`n1. https://contoso.blob.core.windows.net/container/`n2. https://contoso.file.core.windows.net/fileshare/`n3. https://contoso.blob.core.windows.net/container/optionalpath"
            Write-Host "Upload path: " -ForegroundColor Green -NoNewline
            $blobPathUri = [uri](Read-Host)
            $blobPath = ""
            $testBlobPathResult = Test-BlobPath($blobPathUri)
            while ($testBlobPathResult.Length) {
                Write-Host "`nInvalid upload path: $($testBlobPathResult)`n" -ForegroundColor Red
                Write-Host "Upload path: " -ForegroundColor Green -NoNewline
                $blobPathUri = [uri](Read-Host)
                $testBlobPathResult = Test-BlobPath($blobPathUri)
            }
            $blobPath = $blobPathUri.Scheme + "://" + $blobPathUri.Host
            if (!$blobPathUri.IsDefaultPort) {
                $blobPath += ":" + $blobPathUri.Port
            }
            $blobPath += $blobPathUri.LocalPath
            if (!$blobPath.EndsWith("/")) {
                $blobPath = $blobPath += "/"
            }
            Write-Host "`nPlease input the SAS token of " -ForegroundColor Green -NoNewline
            Write-Host $blobPath -ForegroundColor Yellow
            Write-Description "A shared access signature (SAS) token is required for uploading file to the blob container or file share. You can generate the SAS token from Azure Portal. The SAS token will be saved with encryption on your local computer."
            Write-Host "SAS Token: " -NoNewline -ForegroundColor Green
            $sasToken = Read-Host
            $testSasTokenResult = Test-SasToken($sasToken)
            while ($testSasTokenResult.Length) {
                Write-Host "`n$($testSasTokenResult)`n" -ForegroundColor Red
                Write-Host "SAS Token: " -NoNewline -ForegroundColor Green
                $sasToken = Read-Host
                $testSasTokenResult = Test-SasToken($sasToken)
            }
            $global:Entries += @{BlobPath = $blobPath; SasToken = $sasToken }
            if ($global:Entries.Count -lt 3) {
                Write-Host "`nDo you want to configure another upload entry?" -ForegroundColor Green
                Write-Host "`nY: Yes, please."
                Write-Host "N" -NoNewline -ForegroundColor Green
                Write-Host ": No, I am good."
                Write-Host "`nChoose from the menu: " -NoNewline -ForegroundColor Green
                Write-Host "<Enter for " -NoNewline
                Write-Host "N" -NoNewline -ForegroundColor Green
                Write-Host "> " -NoNewline
                $continueInput = Read-Host
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
    if ($PreConfigured) {
        Write-Host "`n" -NoNewline
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
        if ($PreConfigured) {
            Write-Host "EzCopy entry: $($entry.BlobPath) was configured." -ForegroundColor Green
        }
    }
    New-Item -Path $EzCopyDirectory"sas.txt" -ItemType "File" -Value $sasFileContent -Force | Out-Null
}

function Test-SasToken {
    param(
        [string] $sasToken
    )
    if ($sasToken.StartsWith("?")) {
        $sasToken = $sasToken.Substring(1)
    }
    $params = $sasToken.Split("&")
    $sv = $se = $sp = $sig = $false
    foreach ($param in $params) {
        $param = $param.ToLower();
        if ($param.StartsWith("sv=")) {
            $sv = $true
        }
        elseif ($param.StartsWith("se=")) {
            $se = $true
        }
        elseif ($param.StartsWith("sp=")) {
            $sp = $true
            if (!$param.Contains("w")) {
                return "The SAS token lacks Write permission."
            }
        }
        elseif ($param.StartsWith("sig=")) {
            $sig = $true
        }
    }
    if ($sv -and $se -and $sp -and $sig) {
        return ""
    }
    else {
        return "Invalid SAS token."
    }
}

function Test-BlobPath {
    param(
        [uri] $blobPath
    )
    $testBlobPathResult = ""
    if ($blobPath.Scheme -ne "http" -and $blobPath.Scheme -ne "https") {
        return "Upload path only supports HTTP/HTTPS protocol."
    }
    if ($blobPath.LocalPath.Length -lt 2) {
        return "Upload path could not be your root blob URL, please specify the container or file share in the path."
    }
    return $testBlobPathResult
}

Write-Host ""

if ($Install -or $PreConfigured) {
    try {
        Install-EzCopy
        Write-Host "`nEzCopy is installed successfully!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "Installing EzCopy failed with error: $($_)" -ForegroundColor Red
        Write-Host "ScriptStackTrace: `n$($_.ScriptStackTrace)" -ForegroundColor Red
    }
    if ($PreConfigured) {
        $ScriptPath = if ($PSCommandPath -ne $null) { $PSCommandPath }else { $MyInvocation.MyCommand.Definition }
        Remove-Item -LiteralPath $ScriptPath -Force
    }
}
elseif ($Update) {
    try {
        Update-EzCopy
        Write-Host "`nEzCopy is updated successfully!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "Updating EzCopy failed with error: $($_)" -ForegroundColor Red
        Write-Host "ScriptStackTrace: `n$($_.ScriptStackTrace)" -ForegroundColor Red
    }
}
elseif ($Uninstall) {
    Uninstall-EzCopy
    Write-Host "EzCopy is removed successfully!`n" -ForegroundColor Green
}
elseif ($Configure) {
    $global:Entries = @()
    Set-EzCopy
    Write-Host "`nEzCopy is configured successfully!`n" -ForegroundColor Green
}

if ($SciprtExecuteViaFile) {
    Write-Host "Press any key to exit: " -NoNewline
    Read-Host
}