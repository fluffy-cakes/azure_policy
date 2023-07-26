//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-nsg-any-in-destination'
var v_policyDescription = 'Denies NSG configured with ANY in Destination'



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
                        field : 'Microsoft.Network/networkSecurityGroups/securityRules[*].access'
                        equals: 'Allow'
                      }
                      {
                        anyOf: [
                          {
                            field   : 'Microsoft.Network/networkSecurityGroups/securityRules[*].destinationAddressPrefix'
                            equals  : '*'
                          }
                          {
                            field   : 'Microsoft.Network/networkSecurityGroups/securityRules[*].destinationAddressPrefix'
                            equals  : 'Internet'
                          }
                          {
                            field   : 'Microsoft.Network/networkSecurityGroups/securityRules[*].destinationAddressPrefix'
                            contains: '0.0.0.0/0'
                          }
                        ]
                      }
                      {
                        field    : 'Microsoft.Network/networkSecurityGroups/securityRules[*].sourceAddressPrefix'
                        notEquals: 'AzureLoadBalancer'
                      }
                      {
                        field    : 'Microsoft.Network/networkSecurityGroups/securityRules[*].sourceAddressPrefix'
                        notEquals: 'GatewayManager'
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
                field : 'type'
                equals: 'Microsoft.Network/networkSecurityGroups/securityRules'
              }
              {
                field : 'Microsoft.Network/networkSecurityGroups/securityRules/access'
                equals: 'Allow'
              }
              {
                anyOf: [
                  {
                    field   : 'Microsoft.Network/networkSecurityGroups/securityRules/destinationAddressPrefix'
                    equals  : '*'
                  }
                  {
                    field   : 'Microsoft.Network/networkSecurityGroups/securityRules/destinationAddressPrefix'
                    equals  : 'Internet'
                  }
                  {
                    field   : 'Microsoft.Network/networkSecurityGroups/securityRules/destinationAddressPrefix'
                    contains: '0.0.0.0/0'
                  }
                ]
              }
              {
                field    : 'Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix'
                notEquals: 'AzureLoadBalancer'
              }
              {
                field    : 'Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix'
                notEquals: 'GatewayManager'
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
