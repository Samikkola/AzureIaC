using 'main.bicep'

param appName = 'todoapp'
param environment = 'dev'
param location = 'swedencentral'
param dbPassword = readEnvironmentVariable('DB_PASSWORD', '')
