Param(
    # Resource Group Name
    [Parameter(Mandatory = $true, HelpMessage = "Resource Group name.")]
    [ValidateNotNullOrEmpty()]
    $ResourceGroupName = "",
    
    # Storage Account Name
    [Parameter(Mandatory = $true, HelpMessage = "Storage Account Name where the container will be created in")]
    [ValidateNotNullOrEmpty()]
    $StorageAccountName = "",

    # Container Group Name
    [Parameter(Mandatory = $true, HelpMessage = "Container Name to be created")]
    [ValidateNotNullOrEmpty()]
    $ContainerName = "",

    [Parameter(Mandatory = $true, HelpMessage = "Enter Azure Subscription name. You need to be Subscription Admin to execute the script")]
    [ValidateNotNullOrEmpty()]
    [string] $subscriptionName = ""
)

function Get-StorageAccount () {
    $strgAccount = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (!$strgAccount) {
        Write-Host "Storage Account '$StorageAccountName' does not exist. The script will now exit.";
        exit;
    }
    return $strgAccount;
}

function Add-StorageAccountContainer($strgAccount) {
    # Set the context to be the storage account.
    $key1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $strgAccount.ResourceGroupName -name $strgAccount.StorageAccountName)[0].value
    $ctx = New-AzureStorageContext -StorageAccountName $strgAccount.StorageAccountName -StorageAccountKey $key1


    $storageContainer = Get-AzureStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue
    if ($storageContainer) {
        Write-Host "Container '$ContainerName' already exists. The script will now end.";
        exit
    }
    else {
        New-AzureStorageContainer -Name "$ContainerName" -Context $ctx -Permission Blob
    }
}

function Test-ContainerNameValidity()
{
    Write-Host "Testing container name against Microsoft's naming rules."
    try {
        [Microsoft.WindowsAzure.Storage.NameValidator]::ValidateContainerName($ContainerName)
        Write-Host -ForegroundColor Green "Container name is valid!"
        return
    }
    catch {
        Write-Host -ForegroundColor Red "Invalid container name. Please check the container name rules: https://docs.microsoft.com/en-us/rest/api/storageservices/naming-and-referencing-containers--blobs--and-metadata#container-names"
        Write-Host -ForegroundColor Red "The script is now exiting."
        exit
    }
}

#Validate Container name
Import-Module -Name AzureRM
Test-ContainerNameValidity

# Log in to your subscription
Import-Module -Name AzureRM.Profile
Write-Output "Provide your credentials to access Azure subscription $subscriptionName" -Verbose
Login-AzureRmAccount -SubscriptionName $subscriptionName
$azureSubscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $azureSubscription.SubscriptionId

# Create the Azure container
$strgAccount = Get-StorageAccount
Add-StorageAccountContainer($strgAccount)
Write-Host "Done!"
