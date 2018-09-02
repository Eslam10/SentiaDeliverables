###################################################################################
# Author: Eslam Mahmoud
# Contact: eslamsayedattiama@gmail.com
# Creation date: September 2018
# Description: Script for Sentia company assignment
###################################################################################

##Get all temp/param files dirs from FileLocations file
$webFileLocations = Invoke-WebRequest https://raw.githubusercontent.com/Eslam10/SentiaDeliverables/master/FileLocations_RGParameters/FileLocations.txt
$FileLocations    = ConvertFrom-StringData -StringData $webFileLocations.Content

##Deploy on this subscription
Get-AzureRmSubscription –SubscriptionName $FileLocations['SubscriptionName'] | Select-AzureRmSubscription 

echo "############################################Create Resource Group############################################"
$webRGParameters  = Invoke-WebRequest $FileLocations['RGParametersFileLocation']
$webRGTag         = Invoke-WebRequest $FileLocations['RGTagFileLocation']
$RGParameters     = ConvertFrom-StringData -StringData $webRGParameters.Content
$RGTag            = ConvertFrom-StringData -StringData $webRGTag.Content

New-AzureRmResourceGroup @RGParameters -Tag $RGTag -Force;

$RG_Name = $RGParameters['Name'];
echo 'Resource Group Name: ' $RG_Name

echo "############################################Create Storage Account############################################"
New-AzureRmResourceGroupDeployment -ResourceGroupName $RG_Name `
  -TemplateUri $FileLocations['SAtemplate'] `
  -TemplateParameterUri $FileLocations['SAparameters']


echo "############################################Create Virtual Network/Subnets############################################"
New-AzureRmResourceGroupDeployment -ResourceGroupName $RG_Name `
-TemplateUri $FileLocations['VNwktemplate'] -TemplateParameterUri $FileLocations['VNwkparameter']

echo "######################Create Policy Defenition with REST API######################"
##Authentication and getting token for REST API
$azContext     = Get-AzureRmContext
$azProfile     = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token         = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader    = @{
  'Authorization'='Bearer ' + $token.AccessToken
}
 
$SubID = (Get-AzureRmSubscription -SubscriptionName $FileLocations['SubscriptionName']).Id; #To be used in URLPD
$URLPD   = "https://management.azure.com/subscriptions/$SubID/providers/Microsoft.Authorization/policyDefinitions/SentiaPD?api-version=2018-03-01";

$webBodyPDLocations = Invoke-WebRequest $FileLocations['PolicyDefBody'];
$Body_1             = $webBodyPDLocations.Content;

$invokeRestPD = @{
  Uri         = $URLPD
  Method      = 'Put'
  ContentType = 'application/json'
  Headers     = $authHeader
  Body        = $Body_1
 }

# Invoke the REST API
$responsePD = Invoke-RestMethod @invokeRestPD;


$Resp_PD_id = $responsePD.id; #To be used in created Policy assignment based on this policy definition

echo 'Policy Defenition ID: ' $Resp_PD_id;

echo "############################################Create Policy Assignment with REST API############################################"

$webBodyPALocations = Invoke-WebRequest $FileLocations['PolicyAssBody'];
$Body_2             = $webBodyPALocations.Content;
$RG_ID = (Get-AzureRmResourceGroup -Name SentiaRG).ResourceId;

##Update PolicyAssignment body file with RG and created policy definition IDs
echo $Body_2 > C:\Body_PA.json;
echo '"scope":' """$RG_ID""," >> C:\Body_PA.json;
echo '"policyDefinitionId":' """$Resp_PD_id""" "} }" >> C:\Body_PA.json;
$Body_3 =  Get-Content  C:\Body_PA.json;

$URLPA  = "https://management.azure.com/%2Fsubscriptions%2F$SubID%2FresourceGroups%2F$RG_Name/providers/Microsoft.Authorization/policyAssignments/SentiaPA?api-version=2018-03-01"

$invokeRestPA = @{
  Uri         = $URLPA
  Method      = 'Put'
  ContentType = 'application/json'
  Headers     = $authHeader
  Body        = $Body_3
 }

# Invoke the REST API
$responsePA = Invoke-RestMethod @invokeRestPA;

$Resp_PA_id = $responsePA.id;

echo 'Policy Assignment ID: ' $Resp_PA_id;

#Remove temp file created
Remove-Item C:\Body_PA.json;
