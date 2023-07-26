//***** SCOPE *****//

targetScope = 'managementGroup'



//***** VARIABLES *****//

var v_policyName        = 'p-glb-afw-diagnostic-settings-dine'
var v_policyDescription = 'Diagnostic settings to Log Analytics'



//***** RESOURCES *****//

resource pol 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {
  name: v_policyName
  properties: {
    description: v_policyDescription
    displayName: v_policyName
    metadata: {
      category: 'Monitoring'
      version: '1.0.0'
    }
    mode: 'All'
    parameters: {
      logAnalyticsWorkspaceId: {
        type    : 'String'
        metadata: {
          displayName: 'Log Analytics workspace'
          description: 'Log Analytics workspace resource id'
          strongType : 'omsWorkspace'
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
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.Network/azureFirewalls'
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          type: 'Microsoft.Insights/diagnosticSettings'
          name: 'setByPolicy'
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa'
            '/providers/microsoft.authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
          ]
          existenceCondition: {
            allOf: [
              {
                count: {
                  field: 'Microsoft.Insights/diagnosticSettings/logs[*]'
                  where: {
                    allOf: [
                      {
                        field : 'Microsoft.Insights/diagnosticSettings/logs[*].enabled'
                        equals: 'True'
                      }
                      {
                        field : 'Microsoft.Insights/diagnosticSettings/logs[*].categoryGroup'
                        equals: 'allLogs'
                      }
                    ]
                  }
                }
                equals: 1
              }
              {
                field : 'Microsoft.Insights/diagnosticSettings/metrics.enabled'
                equals: 'True'
              }
              {
                field             : 'Microsoft.Insights/diagnosticSettings/workspaceId'
                matchInsensitively: '[parameters(\'logAnalyticsWorkspaceId\')]'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  resourceName: {
                    type: 'string'
                  }
                  logAnalyticsWorkspaceId: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  metricsAndLogsEnabled: {
                    type: 'Bool'
                  }
                }
                variables: {}
                resources: [
                  {
                    type: 'Microsoft.Network/azureFirewalls/providers/diagnosticSettings'
                    apiVersion: '2021-05-01-preview'
                    name: '[concat(parameters(\'resourceName\'), \'/\', \'Microsoft.Insights/setByPolicy\')]'
                    location: '[parameters(\'location\')]'
                    dependsOn: []
                    properties: {
                      workspaceId: '[parameters(\'logAnalyticsWorkspaceId\')]'
                      metrics: [
                        {
                          category: 'AllMetrics'
                          enabled: '[bool(parameters(\'metricsAndLogsEnabled\'))]'
                          retentionPolicy: {
                            days   : 0
                            enabled: false
                          }
                          timeGrain: null
                        }
                      ]
                      logs: [
                        {
                          categoryGroup: 'allLogs'
                          enabled      : '[bool(parameters(\'metricsAndLogsEnabled\'))]'
                        }
                      ]
                    }
                  }
                ]
                outputs: {}
              }
              parameters: {
                logAnalyticsWorkspaceId: {
                  value: '[parameters(\'logAnalyticsWorkspaceId\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
                resourceName: {
                  value: '[field(\'name\')]'
                }
                metricsAndLogsEnabled: {
                  value: '[bool(parameters(\'metricsAndLogsEnabled\'))]'
                }
              }
            }
          }
        }
      }
    }
  }
}

output o_policyId string = pol.id
