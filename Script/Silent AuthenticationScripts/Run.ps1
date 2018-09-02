$ProgressPreference= "SilentlyContinue"

$password = "esso"
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("812b03b9-2fc2-4563-b6f6-1c079a828689", $secpasswd)
Add-AzureRmAccount -ServicePrincipal -Tenant 9eba520f-f1ae-477d-ad1f-96e347c4f653 -Credential $mycreds
Select-AzureRmSubscription -SubscriptionId 98c0bab3-5aa6-4e80-a54b-2a3b2583a13a