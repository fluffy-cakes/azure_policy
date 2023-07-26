//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-gen-allowed-resource-types'
var v_policyDescription = 'Specify the resource types that your organization can deploy'



//***** RESOURCES *****//

resource pol 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: v_policyName
  properties: {
    description: v_policyDescription
    displayName: v_policyName
    metadata: {
      category: 'General'
      version: '1.0.0'
    }
    mode: 'Indexed'
    parameters: {
      listOfResourceTypesAllowed: {
        type: 'Array'
        metadata: {
          description: 'The list of resource types that can be deployed.'
          displayName: 'Allowed resource types'
          strongType : 'resourceTypes'
        }
      }
    }
    policyRule: {
      if: {
        not: {
          field: 'type'
          in   : '[parameters(\'listOfResourceTypesAllowed\')]'
        }
      }
      then: {
        effect: 'deny'
      }
    }
  }
}



//***** OUTPUTS *****//

output o_policyId string = pol.id
