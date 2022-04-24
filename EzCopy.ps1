param (
    [string]$FilePath,
    [string]$BlobPath,
    [string]$FileHash = "none",
    [switch]$Custom = $false
)

class AzCopyResult {
    [string]$Logfile
    [string]$FinalJobStatus
    [string]$ErrorDescription
    [string]$ResponseStatus
    [string]$Raw
    [string]ToString() {
        return ("Final Job Status: {0}`nLog file: {1}`nError Description: {2}`nResponse Status: {3}" -f $this.FinalJobStatus, $this.Logfile, $this.ErrorDescription, $this.ResponseStatus)
    }
}
$azCopyResult = [AzCopyResult]::new()
$SasToken = ""
$fileItem = Get-ChildItem $FilePath
$fileName = $fileItem.Name

$sasFile = $env:LOCALAPPDATA + "\EzCopy\sas.txt"
$azCopy = $env:LOCALAPPDATA + "\EzCopy\azcopy.exe"
$sasLines = Get-Content -Path $sasFile -ErrorAction SilentlyContinue
foreach ($sasLine in $sasLines) {
    if ($sasLine.StartsWith($BlobPath)) {
        [SecureString]$sasSecureStr = $sasLine.split(" ")[1] | ConvertTo-SecureString
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($sasSecureStr)
        $SasToken = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
        break
    }
}

if (!(Test-Path -Path $azCopy) -Or $SasToken -eq "") {
    Write-Host "`nEzCopy is not configured correctly, please reinstall EzCopy.`n`nPress any key to exit"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

if ($Custom) {
    $md5Name = (Get-FileHash -Path $FilePath -Algorithm 'md5').Hash
    $sha256Name = (Get-FileHash -Path $FilePath).Hash
    Write-Host "Please enter the path (without file name) you want to append after " -NoNewline
    Write-Host $BlobPath -ForegroundColor "Cyan" -NoNewline
    $CustomPath = Read-Host
    $BlobPath += $CustomPath
    Write-Host "`nPlease choose the file name you want to save under " -NoNewline
    Write-Host $BlobPath -ForegroundColor "Cyan" -NoNewline
    Write-Host ":`n1. Keep original file name: " -NoNewline
    Write-Host $fileName -ForegroundColor "Yellow"
    Write-Host "2. Use MD5 hash as file name: " -NoNewline
    Write-Host ($md5Name + ($fileItem.Extension)) -ForegroundColor "Yellow"
    Write-Host "3. Use MD5 hash as file name: " -NoNewline
    Write-Host ($sha256Name + ($fileItem.Extension)) -ForegroundColor "Yellow"
    Write-Host "4. Use custom file name"
    Write-Host "`nPlease enter your choice (Default is 1. Keep original file name):" -NoNewline
    switch (Read-Host) {
        '2' { 
            $fileName = $md5Name + $fileItem.Extension
        }
        '3' {
            $fileName = $sha256Name + $fileItem.Extension
        }
        '4' {
            Write-Host "Please enter the file name: " -NoNewline
            $fileName = Read-Host
        }
    }
}
else {
    switch ($FileHash) {
        'md5' {
            $fileName = (Get-FileHash -Path $FilePath -Algorithm 'md5').Hash + $fileItem.Extension
        }
        'sha256' {
            $fileName = (Get-FileHash -Path $FilePath).Hash + $fileItem.Extension
        }
    }
}
if (!$BlobPath.EndsWith('/')) {
    $BlobPath += '/'
}

$UrlPath = $BlobPath + $fileName

Write-Host "`nCopying file " -NoNewline
Write-Host $fileItem.Name -ForegroundColor "Cyan" -NoNewline
Write-Host " to " -NoNewline
Write-Host $BlobPath -ForegroundColor "Cyan" -NoNewline
Write-Host ", please wait...`n"

$cmd = $azCopy + " copy " + $FilePath + " " + $UrlPath + $SasToken
$cmd = $cmd.Replace('&', '"&"')
$azCopyResult.Raw = Invoke-Expression $cmd | Out-String
[Collections.Generic.List[String]]$lines = $azCopyResult.Raw.Split([System.Environment]::NewLine)

$lines.RemoveAll({ param($line) !$line.Length }) | Out-Null



for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.StartsWith("Log file is located at: ")) {
        $azCopyResult.Logfile = $line.Substring("Log file is located at: ".Length)
    }
    elseif ($line.StartsWith(("Final Job Status: "))) {
        $azCopyResult.FinalJobStatus = $line.Substring("Final Job Status: ".Length)
    }
    elseif ($line.StartsWith("===== RESPONSE ERROR") -and $lines[$i + 1].StartsWith("Description=")) {
        $azCopyResult.ErrorDescription = $lines[$i + 1].Substring("Description=".Length)
    }
    elseif ($line.Trim().StartsWith("RESPONSE Status: ")) {
        $azCopyResult.ResponseStatus = $line.Trim().Substring("RESPONSE Status: ".Length)
    }
}

if ($azCopyResult.FinalJobStatus -eq "Completed") {
    $clipboardSet = $false
    try {
        Set-Clipboard -Value $UrlPath
        $clipboardSet = $true
    }
    catch {
        Write-Host "failed to set clipboard"
    }
    Write-Host "File is copied successfully" -ForegroundColor "Green" -NoNewline
    if ($clipboardSet) {
        Write-Host ", the URL is already copied in clipboard: " -NoNewline
    }
    else {
        Write-Host ", the URL is: " -NoNewline
    }
    Write-Host $UrlPath -ForegroundColor "Cyan"
}
else {
    Write-Host "Failed to copy file" -ForegroundColor "Red"
    Write-Host "`nFinal Job status: " -NoNewline
    Write-Host $azCopyResult.FinalJobStatus -ForegroundColor "Red"
    Write-Host "`nError description: " -NoNewline
    Write-Host $azCopyResult.ErrorDescription -ForegroundColor "Red"
    Write-Host "`nResponse Status: " -NoNewline
    Write-Host $azCopyResult.ResponseStatus -ForegroundColor "Red"
    Write-Host "`nYou may find more error details at: " -NoNewline
    Write-Host $azCopyResult.Logfile -ForegroundColor "Cyan"
}

Write-Host "`nPress any key to exit"
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")