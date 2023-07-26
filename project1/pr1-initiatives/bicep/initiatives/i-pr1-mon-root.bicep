//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'i-pr1-mon-root'
var v_policyDescription = 'Monitoring root'



//***** RESOURCES *****//

resource ini 'Microsoft.Authorization/policySetDefinitions@2020-09-01' = {
  name: v_policyName
  properties: {
    policyType: 'Custom'
    displayName: v_policyName
    description: v_policyDescription
    metadata: {
      category: 'Monitoring'
      version: '1.0.0'
    }
    parameters: {
      logAnalyticsWorkspaceId: {
        type: 'String'
        metadata: {
          displayName: 'Log Analytics Workspace ID'
          description: 'Log Analytics Workspace ID'
        }
      }
      metricsAndLogsEnabled: {
        type        : 'String'
        defaultValue: 'True'
        metadata    : {
          displayName: 'Metrics and Logs Enabled'
          description: 'Flag whether metrics and logs collection is enabled or disabled'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: managementGroupResourceId('Microsoft.Authorization/policyDefinitions', 'p-glb-afw-diagnostic-settings-dine')
        parameters: {
          logAnalyticsWorkspaceId: {
            value: '[parameters(\'logAnalyticsWorkspaceId\')]'
          }
          metricsAndLogsEnabled: {
            value: '[parameters(\'metricsAndLogsEnabled\')]'
          }
        }
      }
    ]
  }
}



//***** OUTPUTS *****//

output o_monitoringInitiative object = ini
