//***** SCOPE *****//

targetScope = 'subscription'



//***** VARIABLES *****//

var v_policyName        = 'i-hubPlatform'
var v_policyDescription = 'hubPlatform tests'



//***** RESOURCES *****//

resource ini 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: v_policyName
  properties: {
    policyType: 'Custom'
    displayName: v_policyName
    description: v_policyDescription
    metadata: {
      category: 'Network'
      version: '1.0.0'
    }
    parameters: {
      listOfAllowedPorts: {
        type: 'Array'
        metadata: {
          description: 'The list of ports that can be specified on the azure firewall.'
          displayName: 'Allowed Ports'
        }
      }
      listOfAllowedProtocols: {
        type: 'Array'
        metadata: {
          description: 'The list of protocols that can be specified on the azure firewall.'
          displayName: 'Allowed Protocols'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Management/managementGroups/#{variables.policy_mgmtGroupId}#/providers/Microsoft.Authorization/policyDefinitions/p-glb-afw-apprule-allowed-ports'
        parameters: {
          listOfAllowedPorts: {
            value: '[parameters(\'listOfAllowedPorts\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Management/managementGroups/#{variables.policy_mgmtGroupId}#/providers/Microsoft.Authorization/policyDefinitions/p-glb-afw-apprule-allowed-protocols'
        parameters: {
          listOfAllowedProtocols: {
            value: '[parameters(\'listOfAllowedProtocols\')]'
          }
        }
      }
    ]
  }
}



//***** OUTPUTS *****//

output o_afwInitiative object = ini
