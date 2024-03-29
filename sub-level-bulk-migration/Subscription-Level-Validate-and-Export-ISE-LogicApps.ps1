#===============================================================================
# Microsoft FastTrack for Azure
# List Connectors being used by the Logic Apps in an ISE across all resource groups
# Based on https://github.com/wsilveiranz/iseexportutilities by Wagner Silveira
#===============================================================================
# Copyright © Microsoft Corporation.  All rights reserved.
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY
# OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE.
#===============================================================================
param(
    [Parameter(Mandatory = $true)]
    [string]$subscriptionId,
    [Parameter(Mandatory = $false)]
    [string]$outputCsvPath = "ExportedLogicApps_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv"
)

# Login to Azure
Connect-AzAccount

# Set subscription context
Set-AzContext -Subscription $subscriptionId

# Get access token for the ARM management endpoint
$accessToken = Get-AzAccessToken

# Create Authorization header for the HTTP requests
$authHeader = "Bearer " + $accessToken.Token
$head = @{ "Authorization" = $authHeader }

# Define the validation endpoint URL and export endpoint URL
$validateUrl = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Logic/locations/$region/ValidateWorkflowExport?api-version=2022-09-01-preview"
$exportUrl = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Logic/locations/$region/WorkflowExport?api-version=2022-09-01-preview"

# Initialize an array to store Logic App details
$logicAppDetails = @()

# Get all resource groups in the subscription
$resourceGroups = Get-AzResourceGroup

# Iterate through each resource group
foreach ($resourceGroup in $resourceGroups) {
    $resourceGroupName = $resourceGroup.ResourceGroupName
    
    # Get all the Logic Apps for the current resource group
    Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType 'Microsoft.Logic/workflows' -ExpandProperties | ForEach-Object {
        $itemProperties = $_ | Select-Object Name -ExpandProperty Properties
        if ([bool]$itemProperties.PSObject.Properties['integrationServiceEnvironment']) {
            $logicAppDetail = [PSCustomObject]@{
                ResourceGroupName = $resourceGroupName
                LogicAppName = $_.Name
                LogicAppResourceId = $_.ResourceId
                ExportStatus = "Not Processed"  # Placeholder
                PackageLink = "Not Available"   # Placeholder
                ConnectorDetails = @()          # Array to store connector details
            }

            # Get Logic App Content
            $logicAppJson = Invoke-RestMethod -Uri $_.Properties.definition -Headers $head -ContentType 'application/json' -Method Get
            $logicAppConnections = $logicAppJson.triggers | Where-Object { $_.type -eq "ApiConnection" } | Select-Object -Property name, id
            
            foreach ($connection in $logicAppConnections) {
                $connectorDetail = [PSCustomObject]@{
                    ConnectorName = $connection.name
                    ConnectorId = $connection.id
                }
                $logicAppDetail.ConnectorDetails += $connectorDetail
            }
            
            $logicAppDetails += $logicAppDetail
        }
    }
}

# Output results to CSV
$logicAppDetails | Export-Csv -Path $outputCsvPath -NoTypeInformation

Write-Host "Logic Apps exported: $($logicAppDetails.Count)" -ForegroundColor Green
