// infra/modules/postgresql.bicep
// Kuvaus: Azure Database for PostgreSQL Flexible Server

@description('Azure-sijainti')
param location string

@description('Ympäristö')
param environment string

@description('Sovelluksen nimi')
param appName string

@secure()
@description('PostgreSQL-ylläpitäjän salasana')
param administratorPassword string

@description('PostgreSQL-ylläpitäjän käyttäjätunnus')
param administratorLogin string = 'pgadmin'

// Palvelimen nimi: globaalisti uniikki
var serverName = 'psql-${appName}-${environment}-${uniqueString(resourceGroup().id)}'

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: serverName
  location: location
  sku: {
    name: 'Standard_B1ms'    // Burstable -- halvin vaihtoehto (~12$/kk)
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'    // Kehityksessä ei tarvita
    }
    highAvailability: {
      mode: 'Disabled'                  // Kehityksessä ei tarvita
    }
  }
  tags: {
    Application: appName
    Environment: environment
    ManagedBy: 'Bicep'
  }
}

// Firewall: Salli pääsy Azure-palveluista (App Service)
resource firewallRuleAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Tietokanta
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresServer
  name: 'tododb'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Tulosteet
output serverName string = postgresServer.name
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = database.name

// Connection string App Servicelle (ympäristömuuttuja)
output connectionString string = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Port=5432;Database=tododb;Username=${administratorLogin};Password=${administratorPassword}'
