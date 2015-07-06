#
# Runbook that is copied into the automation account
# This is saved in the solution so that it is part of source control
#
workflow Start-ARMAutomation
{
    #Get Var Data
    $adminPassword = Get-AutomationVariable -Name 'adminPassword';
	$adminUsername = Get-AutomationVariable -Name 'adminUsername';
	$AssetLocation = "https://raw.githubusercontent.com/emdempsey/AccessSoftekPOC/master/AccessSoftekPOC/Templates/";
	$customerPrefix = Get-AutomationVariable -Name 'CustomerPrefix';
	$customerVPNAddress = Get-AutomationVariable -Name 'customerVPNAddress';
	$customerVPNFamily = Get-AutomationVariable -Name 'customerVPNFamily';
	$customerVPNP2SSubnet = Get-AutomationVariable -Name 'customerVPNP2SSubnet';
	$customerVPNPlatform = Get-AutomationVariable -Name 'customerVPNPlatform';
	$customerVPNSubnet = Get-AutomationVariable -Name 'customerVPNSubnet';
	$customerVPNVendor = Get-AutomationVariable -Name 'customerVPNVendor';
	$dnsNameForPublicIP = Get-AutomationVariable -Name 'DNSNameForPublicIP';
	$location = Get-AutomationVariable -Name 'Location';
	$ResourceGroupName = $customerPrefix + 'ResourceGroup';
	$subscriptionName = Get-AutomationVariable -Name 'SubscriptionName';
	$vnetAddressSpacePrefix = Get-AutomationVariable -Name 'VNetAddressSpacePrefix';
	$BetaMFMVMCount = Get-AutomationVariable -Name 'BetaMFMVMCount';
	$BetaOrphVMCount = Get-AutomationVariable -Name 'BetaOrphVMCount';
	$BetaWebVMCount = Get-AutomationVariable -Name 'BetaWebVMCount';
	$ProdMFMVMCount = Get-AutomationVariable -Name 'ProdMFMVMCount';
	$ProdOrphVMCount = Get-AutomationVariable -Name 'ProdOrphVMCount';
	$ProdWebVMCount = Get-AutomationVariable -Name 'ProdWebVMCount';
	$StgMFMVMCount = Get-AutomationVariable -Name 'StageMFMVMCount';
	$StgOrphVMCount = Get-AutomationVariable -Name 'StageOrphVMCount';
	$StgWebVMCount = Get-AutomationVariable -Name 'StageWebVMCount';
	$DevBetaDomainName = Get-AutomationVariable -Name 'DevBetaDomainName';
	$StgProdDomainName = Get-AutomationVariable -Name 'StageProdDomainName';
	$virtualNetworkName = $customerPrefix + "vnet01";
	$sqlServerServiceAccountPassword = Get-AutomationVariable -Name 'sqlServerServiceAccountPassword';
	$sqlServerServiceAccountUsername = Get-AutomationVariable -Name 'sqlServerServiceAccountUsername';
	
	#Convert Passwords to secure string
	$adminPassword = ConvertTo-SecureString -AsPlainText -Force -String $adminPassword;
	$sqlServerServiceAccountPassword = ConvertTo-SecureString -AsPlainText -Force -String $sqlServerServiceAccountPassword;
	
	#Get Credential for the customer subscription
	$credential = Get-AutomationPSCredential -Name 'SubscriptionAccountAdmin';
    
    #Sign into the Subscription
    Write-Output "Adding Azure Account";
    Add-AzureAccount -Credential $credential;
    
    #Select the correct subscription
    Write-Output "Selecting $subscriptionName";
    Select-AzureSubscription -SubscriptionName $subscriptionName;
	
	#Create vars to determine of the parallel environments should deploy
	$devbetacontinue = $true;
	$stgprodcontinue = $true;

	#Run the VNet JSON
	Write-Output "Deploying Virtual Network";
	$TemplateFile = $AssetLocation + "VNet.json";
	New-AzureResourceGroup `
		-Name $ResourceGroupName `
		-Location $location `
		-TemplateFile $TemplateFile `
		-customerLocation $location `
		-customerPrefix $customerPrefix `
		-customerVPNAddress $customerVPNAddress `
		-customerVPNfamily $customerVPNFamily `
		-customerVPNP2SSubnet $customerVPNP2SSubnet `
		-customerVPNPlatform $customerVPNPlatform `
		-customerVPNSubnet $customerVPNSubnet `
		-customerVPNVendor $customerVPNVendor `
		-vnetAddressSpacePrefix $vnetAddressSpacePrefix `
		-Force `
		-Verbose
	
	Parallel
	{
		#Run Public, DevBetaMgmt, StgProdMgmt JSON at the same time
		Write-Output "Deploying Public Resources";
		$workflow:TemplateFile = $workflow:AssetLocation + "Public.json";
		New-AzureResourceGroup `
			-Name $workflow:ResourceGroupName `
			-Location $workflow:location `
			-TemplateFile $workflow:TemplateFile `
			-adminPassword $workflow:adminPassword `
			-adminUsername $workflow:adminUsername `
			-customerLocation $workflow:location `
			-customerPrefix $workflow:customerPrefix `
			-dnsNameForPublicIP $workflow:dnsNameForPublicIP `
			-virtualNetworkName $workflow:virtualNetworkName `
			-Force `
			-Verbose
			
		sequence
		{
			try
			{
				#Run the Management Template
				Write-Output "Deploying the Dev-Beta Mgmt Resources"
				$workflow:TemplateFile = $workflow:AssetLocation + "DevBetaMgmt.json";
				New-AzureResourceGroup `
					-Name $workflow:ResourceGroupName `
					-Location $workflow:location `
					-TemplateFile $workflow:TemplateFile `
					-adminPassword $workflow:adminPassword `
					-adminUsername $workflow:adminUsername `
					-customerLocation $workflow:location `
					-customerPrefix $workflow:customerPrefix `
					-DomainName $workflow:DevBetaDomainName `
					-virtualNetworkName $workflow:virtualNetworkName `
					-Force `
					-Verbose
			}
			catch
			{
				$workflow:devbetacontinue = $false;
			}
			
			#Check if dev and beta can continue
			if($workflow:devbetacontinue)
			{
				#Run the environment templates
				Parallel
				{
					#Dev environment template
					Write-Output "Deploying Dev Environment Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "DevEnv.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:DevBetaDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-vnetAddressSpacePrefix $workflow:vnetAddressSpacePrefix `
						-Force `
						-Verbose
					
					#Beta App template
					Write-Output "Deploying Beta App Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "BetaEnvApp.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:DevBetaDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
						
					#Beta Data Template
					Write-Output "Deploying Beta Data Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "BetaEnvData.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:DevBetaDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
					
					#Beta Web Template
					Write-Output "Deploying Beta Web Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "BetaEnvWeb.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:DevBetaDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose				
				}#End of Parallel
			}#End of if
		}#End of sequence
		
		sequence
		{
			try
			{
				#Run the Management Template
				Write-Output "Deploying Stage-Prod Mgmt Resources";
				$workflow:TemplateFile = $workflow:AssetLocation + "StgProdMgmt.json";
				New-AzureResourceGroup `
					-Name $workflow:ResourceGroupName `
					-Location $workflow:location `
					-TemplateFile $workflow:TemplateFile `
					-adminPassword $workflow:adminPassword `
					-adminUsername $workflow:adminUsername `
					-customerLocation $workflow:location `
					-customerPrefix $workflow:customerPrefix `
					-DomainName $workflow:StgProdDomainName `
					-virtualNetworkName $workflow:virtualNetworkName `
					-Force `
					-Verbose
			}
			catch
			{
				$workflow:stgprodcontinue = $false;
			}
			
			#Check if Stage and Prod can continue
			if($workflow:stgprodcontinue)
			{
				#Run the environment templates
				Parallel
				{
					#Stage App template
					Write-Output "Deploying Stage App Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "StgEnvApp.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:StgProdDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
					
					#Stage Data Template
					Write-Output "Deploying Stage Data Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "StgEnvData.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:StgProdDomainName `
						-sqlServerServiceAccountPassword $workflow:sqlServerServiceAccountPassword `
						-sqlServerServiceAccountUsername $workflow:sqlServerServiceAccountUsername `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
					
					#Stage Web Template
					Write-Output "Deploying Stage Web Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "StgEnvWeb.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:StgProdDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
						
					#Prod App template
					Write-Output "Deploying Prod App Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "ProdEnvApp.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:StgProdDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
					
					#Prod Data Template
					Write-Output "Deploying Prod Data Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "ProdEnvData.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:StgProdDomainName `
						-sqlServerServiceAccountPassword $workflow:sqlServerServiceAccountPassword `
						-sqlServerServiceAccountUsername $workflow:sqlServerServiceAccountUsername `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
					
					#Prod Web Template
					Write-Output "Deploying Prod Web Resources";
					$workflow:TemplateFile = $workflow:AssetLocation + "ProdEnvWeb.json";
					New-AzureResourceGroup `
						-Name $workflow:ResourceGroupName `
						-Location $workflow:location `
						-TemplateFile $workflow:TemplateFile `
						-adminPassword $workflow:adminPassword `
						-adminUsername $workflow:adminUsername `
						-customerLocation $workflow:location `
						-customerPrefix $workflow:customerPrefix `
						-DomainName $workflow:StgProdDomainName `
						-virtualNetworkName $workflow:virtualNetworkName `
						-Force `
						-Verbose
				}#End of Parallel
			}#End of if
		}#End of sequence
	}
}