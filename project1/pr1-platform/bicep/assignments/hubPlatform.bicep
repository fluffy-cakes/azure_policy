//***** SCOPE *****//

targetScope = 'subscription'



//***** PARAMETERS *****//

param p_assignmentParams object



//***** VARIABLES *****//

var v_policyName        = 'a-hubPlatform'
var v_policyDescription = 'hubPlatform tests'



//***** RESOURCES *****//

resource agt 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
  name: 'a-${p_assignmentParams.initiativeName}'
  location: v_longLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    metadata: {
      version: '1.0.0'
    }
    enforcementMode: 'Default'
    policyDefinitionId: '/providers/Microsoft.Management/managementGroups/${p_assignmentParams.initiativeScope}/providers/Microsoft.Authorization/policySetDefinitions/i-${p_assignmentParams.initiativeName}'
    parameters: p_assignmentParams.initiativeParams
  }
}
