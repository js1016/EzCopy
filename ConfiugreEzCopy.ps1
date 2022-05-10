param(
    [switch]$DoInstall = $true
)

$OSArchitecture = (Get-CimInstance -ClassName win32_operatingsystem).OSArchitecture
$EzCopyDirectory = $env:LOCALAPPDATA + "\EzCopy\"
$EzCopyDownloadPath = "https://raw.githubusercontent.com/js1016/EzCopy/main/EzCopy.ps1"
$EzCopySavePath = $EzCopyDirectory + "EzCopy.ps1"
$AzCopyDownloadPath = "https://aka.ms/downloadazcopy-v10-windows-32bit"
$AzCopySavePath = $EzCopyDirectory + "AzCopy.zip"
if ($OSArchitecture.StartsWith("64")) {
    $AzCopyDownloadPath = "https://aka.ms/downloadazcopy-v10-windows"
}

function Download-AzCopy {
    Write-Host "Downloading AzCopy.exe to $($EzCopyDirectory)"
    Start-BitsTransfer $AzCopyDownloadPath $AzCopySavePath
    if (!(Test-Path -Path $AzCopySavePath -PathType Leaf)) {
        Write-Host "Failed to download AzCopy"
        return $false
    }
    Expand-Archive -Path $AzCopySavePath -DestinationPath $EzCopyDirectory -Force
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
        Write-Host "Did not find azcopy.exe after extraction"
        Remove-Item -Path $AzCopySavePath
        return $false
    }
    Remove-Item -Path $AzCopySavePath
    return $true
}

function Download-EzCopy {
    Write-Host "Downloading EzCopy to $($EzCopyDirectory)"
    Start-BitsTransfer $EzCopyDownloadPath $EzCopySavePath
    if (!(Test-Path -Path $EzCopySavePath -PathType Leaf)) {
        return $false
    }
    return $true
}

function Install-EzCopy { 
    Write-Host "Creating EzCopy directory: $($EzCopyDirectory)"
    New-Item -Path $env:LOCALAPPDATA -Name "EzCopy" -ItemType "Directory" -Force | Out-Null
    if (!(Download-AzCopy)) {
    }
    if (!(Download-EzCopy)) {
        
    }
}

if ($DoInstall) {
    Install-EzCopy
}
Read-Host