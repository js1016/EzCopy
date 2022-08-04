# EzCopy

EzCopy is a tiny utility that allows you to quickly copy files to [Azure Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) and [Azure Files](https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction) via context menu on Windows.

You can configure up to three entries in context menu as default file upload paths. You just need to provide the upload path and its [SAS token](https://docs.microsoft.com/en-us/azure/storage/common/storage-sas-overview) during initial setup. EzCopy saves the upload path(s) in plain text and the encrypted SAS token(s) on your computer. Under the hood, EzCopy invokes [AzCopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10) to copy the file.

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-context-menu.png)

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-quick-copy.png)

EzCopy also supports customized upload path and file name:

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-customized-path.png)

## Prerequisites

1. EzCopy supports following Windows versions.
   
   * Windows 7
   * Windows 8
   * Windows 8.1
   * Windows 10
   * Windows 11

2. [Azure Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) or [Azure Files](https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction) is created.
3. Running PowerShell script should be allowed. 
4. You need to get an [SAS token](https://docs.microsoft.com/en-us/azure/storage/common/storage-sas-overview) that has the **Write** permission to the blob URL or the file share URL. See [Appendix: How to obtain the SAS token from Azure Portal?](#appendix-how-to-obtain-the-sas-token-from-azure-portal) for details.

## Install

Download [`ConfigureEzCopy.ps1`](https://github.com/js1016/EzCopy/releases/download/v1.0.1/ConfigureEzCopy.ps1) and launch PowerShell.

1. EzCopy supports both the Windows built-in PowerShell (powershell.exe) and the cross-platform PowerShell (pwsh.exe).
2. You don't have to run the PowerShell as administrator, just run it as the user that you want to have the EzCopy context menu.

CD to the folder where you saved `ConfigureEzCopy.ps1` and run below command to install EzCopy:

```powershell
.\ConfigureEzCopy.ps1 -Install
```

Follow the instruction to finish installation.

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-install.png)

If you get `running script is disabled` error, this means running PowerShell script is not enabled.

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-script-disabled.png)

You need to run PowerShell as administrator and run following command to allow running PowerShell script.

```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```

If you get `script is not digitally signed` error, then please unlock the file from its **Properties**.

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-script-not-signed.png)

![](https://joji.blob.core.windows.net/ezcopy/imgs/ezcopy-unlock-script.png)

## Update

To update EzCopy, please run:

```
& $env:LOCALAPPDATA\EzCopy\ConfigureEzCopy.ps1 -Update
```

## Re-configure

If you want to re-configure the EzCopy upload entries, please run:

```
& $env:LOCALAPPDATA\EzCopy\ConfigureEzCopy.ps1 -Configure
```

## Uninstall

If you want to remove EzCopy, please run:

```
& $env:LOCALAPPDATA\EzCopy\ConfigureEzCopy.ps1 -Uninstall
```

## Appendix: How to obtain the SAS token from Azure Portal?

1. For [Azure Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) and [Azure Files](https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction), you can go to the **Shared access signature** page of your storage account and follow the tips below to obtain an SAS token.

   * Allowed services: choose **Blob** for Blob Storage, choose **File** for File Shares
   * Allowed resource types: **Object** must be selected
   * Allowed permissions: **Write** must be selected
   * Input the desired token expiry date/time

   Then please click the **Generate SAS and connection string** button and you will get the SAS token.

   ![](https://joji.blob.core.windows.net/ezcopy/imgs/102F8C1002111189ECEB52F666FE3AFC.png)

2. For [Azure Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction), you can also obtain an SAS token in Container's **Shared access tokens** page:

   ![](https://joji.blob.core.windows.net/ezcopy/imgs/3CDB50E28B4F8E4161E027FBDD9224B4.png)
