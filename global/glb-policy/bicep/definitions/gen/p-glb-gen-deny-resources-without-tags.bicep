//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-gen-deny-resources-without-tags'
var v_policyDescription = 'Deny resources without tags'



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
    mode: 'indexed'
    parameters: {
      listOfClassifications: {
        type: 'Array'
        metadata: {
          description: 'The list of allowed security classifications'
          displayName: 'Allowed Security Classifications'
        }
        allowedValues: [
          'Confidential'
          'Highly Confidential'
        ]
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            anyOf: [
              {
                field : 'tags[appId]'
                exists: 'false'
              }
              {
                field : 'tags[costCentre]'
                exists: 'false'
              }
              {
                field : 'tags[owner]'
                exists: 'false'
              }
              {
                field : 'tags[classification]'
                exists: 'false'
              }
              {
                not: {
                  field: 'tags[\'classification\']'
                  in   : '[parameters(\'listOfClassifications\')]'
                }
              }
            ]
          }
          {
            not: {
              field: 'type'
              in: [
                'Microsoft.Insights/myWorkbooks'
                'Microsoft.Insights/workbooks'
              ]
            }
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
