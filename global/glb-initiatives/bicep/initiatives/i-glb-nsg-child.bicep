//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'i-glb-nsg-child'
var v_policyDescription = 'NSG Initiative Environment Child'



//***** RESOURCES *****//

resource ini 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: v_policyName
  properties: {
    policyType: 'Custom'
    displayName: v_policyName
    description: v_policyDescription
    metadata: {
      category: 'NSG'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-nsg-any-in-destination')
        parameters: {}
      }
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-nsg-any-in-ports')
        parameters: {}
      }
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-nsg-any-in-source')
        parameters: {}
      }
    ]
  }
}



//***** OUTPUTS *****//

output o_nsgInitiative object = ini
