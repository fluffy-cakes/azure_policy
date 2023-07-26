//***** SCOPE *****//

targetScope = 'managementGroup'



//***** PARAMETERS *****//

param p_assignmentParams array



//***** VARIABLES *****//

var v_policyName        = 'a-assignments'
var v_policyDescription = 'Deployment of Policy Assignments'



//***** RESOURCES *****//

resource agt 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for item in p_assignmentParams: {
  name: 'a-${item.initiativeName}'
  location: v_longLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    metadata: {
      version: '1.0.0'
    }
    enforcementMode: 'Default'
    policyDefinitionId: '/providers/Microsoft.Management/managementGroups/${item.initiativeScope}/providers/Microsoft.Authorization/policySetDefinitions/i-${item.initiativeName}'
    parameters: item.initiativeParams
  }
}]
