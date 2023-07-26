//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'i-glb-gen-root'
var v_policyDescription = 'General Initiative Environment Root'



//***** RESOURCES *****//

resource ini 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: v_policyName
  properties: {
    policyType: 'Custom'
    displayName: v_policyName
    description: v_policyDescription
    metadata: {
      category: 'General'
      version: '1.0.0'
    }
    parameters: {
      listOfAllowedLocations: {
        type: 'Array'
        metadata: {
          displayName: 'List of allowed locations'
          description: 'List of allowed locations'
        }
        allowedValues: [
          'uksouth'
          'ukwest'
        ]
      }
      listOfResourceTypesAllowed: {
        type: 'Array'
        metadata: {
          displayName: 'List of allowed resources'
          description: 'List of allowed resources'
        }
      }
      listOfClassifications: {
        type: 'Array'
        metadata: {
          displayName: 'List of allowed security classifications'
          description: 'List of allowed security classifications'
        }
        allowedValues: [
          'Confidential'
          'Highly Confidential'
        ]
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-gen-allowed-locations')
        parameters: {
          listOfAllowedLocations: {
            value: '[parameters(\'listOfAllowedLocations\')]'
          }
        }
      }
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-gen-allowed-resource-types')
        parameters: {
          listOfResourceTypesAllowed: {
            value: '[parameters(\'listOfResourceTypesAllowed\')]'
          }
        }
      }
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-gen-deny-resources-without-tags')
        parameters: {
          listOfClassifications: {
            value: '[parameters(\'listOfClassifications\')]'
          }
        }
      }
    ]
  }
}



//***** OUTPUTS *****//

output o_generalInitiative object = ini
