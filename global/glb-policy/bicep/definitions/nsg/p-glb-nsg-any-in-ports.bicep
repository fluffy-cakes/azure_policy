//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-nsg-any-in-ports'
var v_policyDescription = 'Denies NSG configured with ANY in ports'



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
    mode: 'Indexed'
    parameters:{}
    policyRule: {
      if: {
        anyOf: [
          {
            allOf: [
              {
                field : 'type'
                equals: 'Microsoft.Network/networkSecurityGroups'
              }
              {
                count: {
                  field: 'Microsoft.Network/networkSecurityGroups/securityRules[*]'
                  where: {
                    allOf: [
                      {
                        field    : 'Microsoft.Network/networkSecurityGroups/securityRules[*].access'
                        equals   : 'Allow'
                      }
                      {
                        field    : 'Microsoft.Network/networkSecurityGroups/securityRules[*].destinationPortRange'
                        equals   : '*'
                      }
                      {
                        field    : 'Microsoft.Network/networkSecurityGroups/securityRules[*].sourceAddressPrefix'
                        notEquals: 'AzureLoadBalancer'
                      }
                    ]
                  }
                }
                greater: 0
              }
            ]
          }
          {
            allOf: [
              {
                field    : 'type'
                equals   : 'Microsoft.Network/networkSecurityGroups/securityRules'
              }
              {
                field    : 'Microsoft.Network/networkSecurityGroups/securityRules/access'
                equals   : 'Allow'
              }
              {
                field    : 'Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange'
                equals   : '*'
              }
              {
                field    : 'Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix'
                notEquals: 'AzureLoadBalancer'
              }
            ]
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
