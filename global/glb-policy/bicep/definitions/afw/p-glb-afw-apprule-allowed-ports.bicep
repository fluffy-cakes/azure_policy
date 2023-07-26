//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-afw-apprule-allowed-ports'
var v_policyDescription = 'AZFW apprules allowed ports'



//***** RESOURCES *****//

resource pol 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: v_policyName
  properties: {
    description: v_policyDescription
    displayName: v_policyName
    metadata: {
      category: 'Network'
      version: '1.0.0'
    }
    mode: 'All'
    parameters: {
      listOfAllowedPorts: {
        type: 'Array'
        metadata: {
          description: 'The list of ports that can be specified on the azure firewall.'
          displayName: 'Allowed Ports'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
          field : 'Microsoft.Network/azureFirewalls/applicationRuleCollections'
          exists: 'true'
          }
          {
          field : 'Microsoft.Network/azureFirewalls/applicationRuleCollections[*].rules[*].protocols[*].port'
          notIn : '[parameters(\'listOfAllowedPorts\')]'
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}



//***** OUTPUTS *****//

output o_policyId string = pol.id
