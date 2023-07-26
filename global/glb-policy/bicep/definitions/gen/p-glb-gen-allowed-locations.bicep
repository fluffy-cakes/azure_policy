//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-gen-allowed-locations'
var v_policyDescription = 'Restrict the locations your organization can specify when deploying resources.'



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
      listOfAllowedLocations: {
        type: 'Array'
        metadata: {
          description: 'The list of locations that can be specified when deploying resources.'
          displayName: 'Allowed locations'
          strongType : 'location'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field    : 'location'
            notIn    : '[parameters(\'listOfAllowedLocations\')]'
          }
          {
            field    : 'location'
            notEquals: 'global'
          }
          {
            field    : 'type'
            notEquals: 'Microsoft.AzureActiveDirectory/b2cDirectories'
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
