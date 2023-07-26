//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-afw-apprule-allowed-protocols'
var v_policyDescription = 'AZFW apprules allowed protocols'



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
      listOfAllowedProtocols: {
        type: 'Array'
        metadata: {
          description: 'The list of protocols that can be specified on the azure firewall.'
          displayName: 'Allowed Protocols'
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
          field : 'Microsoft.Network/azureFirewalls/applicationRuleCollections[*].rules[*].protocols[*].protocolType'
          notIn : '[parameters(\'listOfAllowedProtocols\')]'
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
