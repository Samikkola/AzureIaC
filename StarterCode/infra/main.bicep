// infra/main.bicep
// Kuvaus: TodoApp Azure-infrastruktuurin päätemplate
targetScope = 'subscription'

// ─── PARAMETRIT ───

@description('Sovelluksen nimi, käytetään resurssien nimeämisessä')
param appName string

@allowed(['dev', 'prod'])
@description('Ympäristö')
param environment string = 'dev'

@description('Azure-sijainti')
param location string = 'swedencentral'

@secure()
@description('PostgreSQL-ylläpitäjän salasana')
param dbPassword string


// ─── MUUTTUJAT ───

var resourceGroupName = 'rg-${appName}-${environment}'

var tags = {
  Application: appName
  Environment: environment
  ManagedBy: 'Bicep'
}

// ─── RESURSSIT ───

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// PostgreSQL Flexible Server
module postgresql 'modules/postgresql.bicep' = {
  name: 'postgresqlDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
    appName: appName
    administratorPassword: dbPassword
  }
}

// 3. App Service (Web App, .NET 8 natiivi)
module appService 'modules/appservice.bicep' = {
  name: 'appServiceDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
    appName: appName
    databaseConnectionString: postgresql.outputs.connectionString
  }
}

// ─── TULOSTEET ───

output resourceGroupName string = rg.name
output postgresServerFqdn string = postgresql.outputs.serverFqdn
output webAppName string = appService.outputs.webAppName
output webAppUrl string = appService.outputs.webAppUrl
