# ─────────────────────────────────────────────────────────────────
# deploy‐judge0.ps1
# PowerShell script to deploy Judge0 on Azure Container Apps
# ─────────────────────────────────────────────────────────────────

# === 1. Edit these to match your existing setup: ===
$ResourceGroup   = 'Res-ByteGrade'
$Location        = 'centralus'
$ContainerEnv    = 'judge0-env'
$AcrName         = 'judge0acr'
$AcrLoginServer  = "$AcrName.azurecr.io"
$AcrUser         = (az acr credential show `
                     --name $AcrName `
                     --query username -o tsv)
$AcrPass         = (az acr credential show `
                     --name $AcrName `
                     --query passwords[0].value -o tsv)

# === 2. Deploy Redis ===
az containerapp create `
  --name redis `
  --resource-group $ResourceGroup `
  --environment $ContainerEnv `
  --image $AcrLoginServer/redis:7.2.4 `
  --registry-server $AcrLoginServer `
  --registry-username $AcrUser `
  --registry-password $AcrPass `
  --env-vars REDIS_PASSWORD='swny8TSFcD' `
  --command "redis-server --requirepass swny8TSFcD --appendonly no" `
  --target-port 6379 `
  --ingress internal

# === 3. Deploy PostgreSQL ===
az containerapp create `
  --name postgres `
  --resource-group $ResourceGroup `
  --environment $ContainerEnv `
  --image $AcrLoginServer/postgres:16.2 `
  --registry-server $AcrLoginServer `
  --registry-username $AcrUser `
  --registry-password $AcrPass `
  --env-vars `
      POSTGRES_USER='judge0' `
      POSTGRES_PASSWORD='swny8TSFcD' `
      POSTGRES_DB='judge0' `
  --target-port 5432 `
  --ingress internal

# === 4. Deploy Judge0 Server ===
az containerapp create `
  --name judge0-server `
  --resource-group $ResourceGroup `
  --environment $ContainerEnv `
  --image $AcrLoginServer/judge0:latest `
  --registry-server $AcrLoginServer `
  --registry-username $AcrUser `
  --registry-password $AcrPass `
  --env-vars `
      REDIS_HOST='redis' `
      REDIS_PORT='6379' `
      REDIS_PASSWORD='swny8TSFcD' `
      POSTGRES_USER='judge0' `
      POSTGRES_PASSWORD='swny8TSFcD' `
      POSTGRES_DB='judge0' `
      DATABASE_URL='postgresql://judge0:swny8TSFcD@postgres:5432/judge0' `
  --target-port 2358 `
  --ingress external

# === 5. Deploy Judge0 Worker ===
az containerapp create `
  --name judge0-worker `
  --resource-group $ResourceGroup `
  --environment $ContainerEnv `
  --image $AcrLoginServer/judge0:latest `
  --registry-server $AcrLoginServer `
  --registry-username $AcrUser `
  --registry-password $AcrPass `
  --env-vars `
      REDIS_HOST='redis' `
      REDIS_PORT='6379' `
      REDIS_PASSWORD='swny8TSFcD' `
      POSTGRES_USER='judge0' `
      POSTGRES_PASSWORD='swny8TSFcD' `
      POSTGRES_DB='judge0' `
      DATABASE_URL='postgresql://judge0:swny8TSFcD@postgres:5432/judge0' `
  --command "./scripts/workers" `
  --ingress internal

# === 6. Show Judge0 Server FQDN ===
az containerapp show `
  --name judge0-server `
  --resource-group $ResourceGroup `
  --query properties.configuration.ingress.fqdn `
  -o tsv
