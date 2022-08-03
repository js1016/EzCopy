param (
    [string]$FilePath,
    [string]$BlobPath,
    [string]$FileHash = "none",
    [switch]$Custom = $false
)

function Get-Hash {
    <#
    .SYNOPSIS
    Get-Hash is a PowerShell Version 2 port of Get-FileHash that supports hashing files, as well as, strings.
    .PARAMETER InputObject
    This is the actual item used to calculate the hash. This value will support [Byte[]] or [System.IO.Stream] objects.
    .PARAMETER FilePath
    Specifies the path to a file to hash. Wildcard characters are permitted.
    .PARAMETER Text
    A string to calculate a cryptographic hash for.
    .PARAMETER Encoding
    Specified the character encoding to use for the string passed to the Text parameter. The default encoding type is Unicode. The acceptable values for this parameter are:
    - ASCII
    - BigEndianUnicode
    - Default
    - Unicode
    - UTF32
    - UTF7
    - UTF8
    .PARAMETER Algorithm
    Specifies the cryptographic hash function to use for computing the hash value of the contents of the specified file. A cryptographic hash function includes the property that it is not possible to find two distinct inputs that generate the same hash values. Hash functions are commonly used with digital signatures and for data integrity. The acceptable values for this parameter are:
    
    - SHA1
    - SHA256
    - SHA384
    - SHA512
    - MACTripleDES
    - MD5
    - RIPEMD160
    
    If no value is specified, or if the parameter is omitted, the default value is SHA256.
    For security reasons, MD5 and SHA1, which are no longer considered secure, should only be used for simple change validation, and should not be used to generate hash values for files that require protection from attack or tampering.
    .NOTES
    
    This function was adapted from https://p0w3rsh3ll.wordpress.com/2015/02/05/backporting-the-get-filehash-function/
    Author: Jared Atkinson (@jaredcatkinson)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
    .EXAMPLE
    Get-Hash -Text 'This is a string'
    .EXAMPLE
    Get-Hash -FilePath C:\This\is\a\filepath.exe
    #>

    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Object')]
        $InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        [ValidateNotNullOrEmpty()]
        $FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Text')]
        [string]
        [ValidateNotNullOrEmpty()]
        $Text,

        [Parameter(ParameterSetName = 'Text')]
        [string]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        $Encoding = 'Unicode',

        [Parameter()]
        [string]
        [ValidateSet("MACTripleDES", "MD5", "RIPEMD160", "SHA1", "SHA256", "SHA384", "SHA512")]
        $Algorithm = "SHA256"
    )

    switch ($PSCmdlet.ParameterSetName) {
        File {
            try {
                $FullPath = Resolve-Path -Path $FilePath -ErrorAction Stop
                $InputObject = [System.IO.File]::OpenRead($FilePath)
                Get-Hash -InputObject $InputObject -Algorithm $Algorithm
            }
            catch {
                $retVal = New-Object -TypeName psobject -Property @{
                    Algorithm = $Algorithm.ToUpperInvariant()
                    Hash      = $null
                }
            }
        }
        Text {
            $InputObject = [System.Text.Encoding]::$Encoding.GetBytes($Text)
            Get-Hash -InputObject $InputObject -Algorithm $Algorithm
        }
        Object {
            if ($InputObject.GetType() -eq [Byte[]] -or $InputObject.GetType().BaseType -eq [System.IO.Stream]) {
                # Construct the strongly-typed crypto object
                $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)

                # Compute file-hash using the crypto object
                [Byte[]] $computedHash = $Hasher.ComputeHash($InputObject)
                [string] $hash = [BitConverter]::ToString($computedHash) -replace '-', ''

                $retVal = New-Object -TypeName psobject -Property @{
                    Algorithm = $Algorithm.ToUpperInvariant()
                    Hash      = $hash
                }

                $retVal
            }
        }
    }
}

function Get-FileHashEx {
    param(
        [string]$Path,
        [string]$Algorithm = "SHA256"
    )
    if (Get-Command "Get-FileHash" -ErrorAction SilentlyContinue) {
        Get-FileHash -Path $Path -Algorithm $Algorithm
    }
    else {
        Get-Hash -FilePath $Path -Algorithm $Algorithm
    }
}

function Set-ClipboardEx {
    param(
        [string]$Value
    )
    $clipPath = $env:SystemRoot + "\System32\clip.exe"
    if (Get-Command "Set-Clipboard" -ErrorAction SilentlyContinue) {
        Set-Clipboard -Value $Value
        return $true
    }
    elseif (Test-Path $clipPath) {
        $expression = "'$($Value)' | $($clipPath)"
        Invoke-Expression $expression
        return $true
    }
    else {
        return $false
    }
}

$jobResult = [PSCustomObject]@{
    LogFile          = ''
    FinalJobStatus   = ''
    ErrorDescription = ''
    ResponseStatus   = ''
    Raw              = ''
}

$SasToken = ""
$fileItem = Get-ChildItem $FilePath
$fileName = $fileItem.Name

$sasFile = $env:LOCALAPPDATA + "\EzCopy\sas.txt"
$azCopy = $env:LOCALAPPDATA + "\EzCopy\azcopy.exe"
$sasLines = Get-Content -Path $sasFile -ErrorAction SilentlyContinue
foreach ($sasLine in $sasLines) {
    if ($sasLine.StartsWith($BlobPath)) {
        $sasSecureStr = $sasLine.split(" ")[1] | ConvertTo-SecureString
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($sasSecureStr)
        $SasToken = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
        break
    }
}

if (!$SasToken.StartsWith("?")) {
    $SasToken = "?$($SasToken)"
}

if (!(Test-Path -Path $azCopy) -Or $SasToken -eq "") {
    Write-Host "`nEzCopy is not configured correctly, please reinstall EzCopy.`n`nPress any key to exit"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

if ($Custom) {
    $md5Name = (Get-FileHashEx -Path $FilePath -Algorithm 'md5').Hash
    $sha256Name = (Get-FileHashEx -Path $FilePath).Hash
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
            $fileName = (Get-FileHashEx -Path $FilePath -Algorithm 'md5').Hash + $fileItem.Extension
        }
        'sha256' {
            $fileName = (Get-FileHashEx -Path $FilePath).Hash + $fileItem.Extension
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

$cmd = $azCopy + " copy '" + $FilePath + "' '" + $UrlPath + $SasToken + "'"
$cmd = $cmd.Replace('&', '"&"')
$jobResult.Raw = Invoke-Expression $cmd | Out-String
[Collections.Generic.List[String]]$lines = $jobResult.Raw.Split([System.Environment]::NewLine)

$lines.RemoveAll({ param($line) !$line.Length }) | Out-Null



for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.StartsWith("Log file is located at: ")) {
        $jobResult.Logfile = $line.Substring("Log file is located at: ".Length)
    }
    elseif ($line.StartsWith(("Final Job Status: "))) {
        $jobResult.FinalJobStatus = $line.Substring("Final Job Status: ".Length)
    }
    elseif ($line.StartsWith("===== RESPONSE ERROR") -and $lines[$i + 1].StartsWith("Description=")) {
        $jobResult.ErrorDescription = $lines[$i + 1].Substring("Description=".Length)
    }
    elseif ($line.Trim().StartsWith("RESPONSE Status: ")) {
        $jobResult.ResponseStatus = $line.Trim().Substring("RESPONSE Status: ".Length)
    }
    elseif ($line.StartsWith("failed to")) {
        $jobResult.ErrorDescription = $line
    }
}

if ($jobResult.FinalJobStatus -eq "Completed") {
    $clipboardSet = Set-ClipboardEx -Value $UrlPath
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
    Write-Host "Failed to copy file. " -ForegroundColor "Red" -NoNewline
    Write-Host "Command: $($cmd)"
    if ($null -ne $jobResult.FinalJobStatus) {
        Write-Host "`nFinal Job status: " -NoNewline
        Write-Host $jobResult.FinalJobStatus -ForegroundColor "Red"
    }
    if ($null -ne $jobResult.ErrorDescription) {
        Write-Host "`nError description: " -NoNewline
        Write-Host $jobResult.ErrorDescription -ForegroundColor "Red"
    }
    if ($null -ne $jobResult.ResponseStatus) {
        Write-Host "`nResponse Status: " -NoNewline
        Write-Host $jobResult.ResponseStatus -ForegroundColor "Red"
    }
    if ($null -ne $jobResult.Logfile) {
        Write-Host "`nYou may find more error details at: " -NoNewline
        Write-Host $jobResult.Logfile -ForegroundColor "Cyan"
    }
}

Write-Host "`nPress any key to exit"
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null