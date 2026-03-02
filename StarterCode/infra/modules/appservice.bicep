// infra/modules/appservice.bicep
// Kuvaus: App Service Plan + Web App (.NET 8 natiivi)

@description('Azure-sijainti')
param location string

@description('Ympäristö')
param environment string

@description('Sovelluksen nimi')
param appName string

@description('PostgreSQL connection string')
@secure()
param databaseConnectionString string

// ─── MUUTTUJAT ───

var appServicePlanName = 'asp-${appName}-${environment}'
var webAppName = 'app-${appName}-${environment}-${uniqueString(resourceGroup().id)}'

// ─── APP SERVICE PLAN ───

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'              // Basic -- halvin taso joka tukee AlwaysOn:ia
  }
  properties: {
    reserved: true           // true = Linux
  }
  tags: {
    Application: appName
    Environment: environment
    ManagedBy: 'Bicep'
  }
}

// ─── WEB APP ───

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'    // Natiivi .NET 8 runtime
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: '/health'           // Käyttää sovelluksen health-endpointia
      appSettings: [
        {
          // ─── TÄMÄ ON AVAINASETUS ───
          // Asettaa tietokantayhteyden ympäristömuuttujaksi.
          // ASP.NET Core lukee tämän automaattisesti:
          //   builder.Configuration.GetConnectionString("DefaultConnection")
          name: 'ConnectionStrings__DefaultConnection'
          value: databaseConnectionString
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment == 'prod' ? 'Production' : 'Development'
        }
      ]
    }
  }
  tags: {
    Application: appName
    Environment: environment
    ManagedBy: 'Bicep'
  }
}

// ─── TULOSTEET ───

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
