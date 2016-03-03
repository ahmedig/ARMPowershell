#General
$Location = "eastus"
$ResourceGroupName = "BarCampPowerShell" + "ResourceGroup"


# Subscription Info
$azureUserName = "something@something.onmicrosoft.com"
$azurePassword = "yourUser's password"
$AzureSubscriptionId = ""

# Virtual Machine
$AzureVMUsername = "username12"
$AzureVMPassword = "2CMXcL8y1eFvGBK6mLt53"

# Web App
$WebAppName = "BarCampPowerShellWebApp"
$AppServicePlanWorkers = 1
$AppServicePlanWorkerSize = "Small"
$AppServicePlanTier = "Standard"
$ServicePlanName = "BarCampPowerShellServicePlan"

# Database
$DbServerUserName = "DbSerberUserName@398"
$DbServerUserPassword = "MyFunkyPassCode@453"
$DbServerName = "barcamppowershelldbserver23"
$DbInstanceName = "BarCampPowershellDbInstance"

# Virtual Machine
	$StorageName = "storageaccountbarcamp"
	$StorageType = "Standard_LRS"

	## Network
	$InterfaceName = "ServerInterface06"
	$Subnet1Name = "Subnet1"
	$VNetName = "VNet09"
	$VNetAddressPrefix = "10.0.0.0/16"
	$VNetSubnetAddressPrefix = "10.0.0.0/24"

	## Compute
	$VMName = "VirtualMachine12"
	$ComputerName = "Server22"
	$VMSize = "Standard_A1"
	$OSDiskName = $VMName + "OSDisk"


function Write-InfoMessage($message)
{
    Write-Host $message -ForegroundColor Green
}

function LoginToSubscription()
{
    Write-InfoMessage "Loggin in"
    $azurePasswordEncrypted = $azurePassword |ConvertTo-SecureString -AsPlainText -Force
    $azureCredential = New-Object -TypeName pscredential -ArgumentList $azureUsername,$azurePasswordEncrypted
    Login-AzureRmAccount -Credential $azureCredential -SubscriptionId $AzureSubscriptionId
    #Login-AzureRmAccount
    #Select-AzureRmSubscription -SubscriptionId $AzureSubscriptionId
    Write-InfoMessage "Logged in successfully"
}

function Create-ResourceGroup()
{
    Write-InfoMessage "Creating Resource Group '$ResourceGroupName' if not exists"
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Force
    Write-InfoMessage "Resource Group '$ResourceGroupName' created successfully"
}

function Create-WebApp()
{
	Create-AppServicePlan
	Create-WebAppResource
}

function Create-AppServicePlan()
{
    Write-InfoMessage "Creating App Service plan: $ServicePlanName"    
    $resource = Find-AzureRmResource -ResourceNameContains $ServicePlanName -ResourceGroupNameContains $ResourceGroupName -ResourceType "Microsoft.Web/ServerFarms"
    if(!$resource)
    {
        $servicePlan = New-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $ServicePlanName `
			-Location $Location -Tier $AppServicePlanTier -NumberofWorkers $AppServicePlanWorkers `
			-WorkerSize $AppServicePlanWorkerSize
		
		$servicePlanv
        Write-InfoMessage "App Service plan created successfully"    
    }
    else
    {
        Write-InfoMessage "App service plan '$ServicePlanName' already exists"        
    }
}

function Create-WebAppResource()
{
	Write-InfoMessage "Creating Web App: $WebAppName"
    $resource = Find-AzureRmResource -ResourceNameContains $WebAppName -ResourceGroupNameContains $ResourceGroupName -ResourceType "Microsoft.Web/sites"
    if(!$resource)
    {
        $webApp = New-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName `
			-Location $Location -AppServicePlan $ServicePlanName
        $webApp
        Write-InfoMessage "Web App created successfully"
    }
    else
    {
        Write-InfoMessage "Web App '$WebAppName' already exists"
    }
}

function Create-Database()
{
	Create-DatabaseServer
	Create-DatabaseResource
}

function Create-DatabaseServer()
{
    Write-InfoMessage "Creating a database server '$DbServerName'"
    $passwordEncrypted = $DbServerUserPassword |ConvertTo-SecureString -AsPlainText -Force
    $adminCredential = New-Object -TypeName pscredential -ArgumentList $DbServerUserName,$passwordEncrypted

	New-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -Location $Location `
		-ServerName $DbServerName -SqlAdministratorCredentials $adminCredential -ServerVersion "12.0"
    Write-InfoMessage "Database server created successfully"
}

function Create-DatabaseResource()
{
    Write-InfoMessage "Creating the database '$DbInstanceName'"
	New-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $DbServerName `
		-DatabaseName $DbInstanceName
    Write-InfoMessage "Database server created successfully"
}

function Create-VM()
{
    Write-InfoMessage "Creating a storage account '$StorageName'"
	# Storage
	$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageName -Type $StorageType -Location $Location
    Write-InfoMessage "Storage account created successfully '$StorageName'"


    Write-InfoMessage "Creating a virtual machine '$VMName'"
	# Network
	$PIp = New-AzureRmPublicIpAddress -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic
	$SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $Subnet1Name -AddressPrefix $VNetSubnetAddressPrefix
	$VNet = New-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $SubnetConfig
	$Interface = New-AzureRmNetworkInterface -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $PIp.Id

	# Compute

	## Setup local VM object
	#$Credential = Get-Credential
    $encryptedVMPassword = $AzureVMPassword |ConvertTo-SecureString -AsPlainText -Force
    $Credential = New-Object -TypeName pscredential -ArgumentList $AzureVMUsername,$encryptedVMPassword


	$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
	$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
	$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
	$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
	$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
	$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

	## Create the VM in Azure
	New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
    Write-InfoMessage "virtual machine created succesfully'$VMName'"
}
Write-InfoMessage "End!"



LoginToSubscription

Create-ResourceGroup 

Create-WebApp

Create-VM

Create-Database