using './main.bicep'

// General Parameters
param parLocations = [
  '<region-1>'
  '<region-2>'
]
param parEnableTelemetry = true

param platformIdentityConfig = {
  createOrUpdateManagementGroup: true
  managementGroupName: 'identity'
  managementGroupParentId: 'platform'
  managementGroupIntermediateRootName: 'alz'
  managementGroupDisplayName: 'Identity'
  managementGroupDoNotEnforcePolicyAssignments: []
  managementGroupExcludedPolicyAssignments: []
  customerRbacRoleDefs: []
  customerRbacRoleAssignments: []
  customerPolicyDefs: []
  customerPolicySetDefs: []
  customerPolicyAssignments: []
  subscriptionsToPlaceInManagementGroup: ['802cc753-a3f4-4831-af31-f99442b7dd15']
  waitForConsistencyCounterBeforeCustomPolicyDefinitions: 10
  waitForConsistencyCounterBeforeCustomPolicySetDefinitions: 10
  waitForConsistencyCounterBeforeCustomRoleDefinitions: 10
  waitForConsistencyCounterBeforePolicyAssignments: 40
  waitForConsistencyCounterBeforeRoleAssignments: 40
  waitForConsistencyCounterBeforeSubPlacement: 10
}

// Only specify the parameters you want to override - others will use defaults from JSON files
param parPolicyAssignmentParameterOverrides = {
    // No policy assignments in platform-identity currently
}
