using './main.bicep'

// General Parameters
param parLocations = [
  '<region-1>'
  '<region-2>'
]
param parEnableTelemetry = true

param platformConfig = {
  createOrUpdateManagementGroup: true
  managementGroupName: 'platform'
  managementGroupParentId: 'alz'
  managementGroupIntermediateRootName: 'alz'
  managementGroupDisplayName: 'Platform'
  managementGroupDoNotEnforcePolicyAssignments: []
  managementGroupExcludedPolicyAssignments: []
  customerRbacRoleDefs: []
  customerRbacRoleAssignments: []
  customerPolicyDefs: []
  customerPolicySetDefs: []
  customerPolicyAssignments: []
  subscriptionsToPlaceInManagementGroup: []
  waitForConsistencyCounterBeforeCustomPolicyDefinitions: 10
  waitForConsistencyCounterBeforeCustomPolicySetDefinitions: 10
  waitForConsistencyCounterBeforeCustomRoleDefinitions: 10
  waitForConsistencyCounterBeforePolicyAssignments: 40
  waitForConsistencyCounterBeforeRoleAssignments: 40
  waitForConsistencyCounterBeforeSubPlacement: 10
}

// Only specify the parameters you want to override - others will use defaults from JSON files
param parPolicyAssignmentParameterOverrides = {
  'Deploy-VM-ChangeTrack': {
    parameters: {
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-ct-alz-${parLocations[0]}'
      }
      userAssignedIdentityResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-VM-Monitoring': {
    parameters: {
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-vmi-alz-${parLocations[0]}'
      }
      userAssignedIdentityResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-VMSS-ChangeTrack': {
    parameters: {
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-ct-alz-${parLocations[0]}'
      }
      userAssignedIdentityResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-VMSS-Monitoring': {
    parameters: {
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-vmi-alz-${parLocations[0]}'
      }
      userAssignedIdentityResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-vmArc-ChangeTrack': {
    parameters: {
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-ct-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-vmHybr-Monitoring': {
    parameters: {
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-vmi-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-MDFC-DefSQL-AMA': {
    parameters: {
      userWorkspaceResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.OperationalInsights/workspaces/law-alz-${parLocations[0]}'
      }
      dcrResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.Insights/dataCollectionRules/dcr-mdfcsql-alz-${parLocations[0]}'
      }
      userAssignedIdentityResourceId: {
        value: '/subscriptions/e565f5da-3c3d-4791-a815-b4c11a4d4d30/resourceGroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-alz-${parLocations[0]}'
      }
    }
  }
  'DenyAction-DeleteUAMIAMA': {
    parameters: {
      resourceName: {
        value: 'mi-alz-${parLocations[0]}'
      }
    }
  }
}
