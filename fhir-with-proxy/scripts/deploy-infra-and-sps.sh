#!/usr/bin/env bash
set -euo pipefail

# Find the path on the system of the script and repo
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR="${SCRIPT_DIR}/.."

# Load from .env file from repo root
unset RESOURCE_GROUP; unset LOCATION; unset PRIVATE_SP; unset PUBLIC_SP; unset FUNCTION_SP; unset PREFIX;
if [ -f "${REPO_DIR}/.env" ]
then
  set -a
  export $(cat "${REPO_DIR}/.env" | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" | xargs)
  set +a
fi

# Ensure the azure cli is logged in
if ! az account show &> /dev/null
then
    echo -e "\033[0;31m You must login to the azure cli before running this script.\033[0m\n"
    exit 1
fi

# Check Prefix Length
echo $PREFIX
echo ${#PREFIX}
if [[ ${#PREFIX} -gt 15 ]]
then
  echo -e "\033[0;31m Prefix must be 15 characters or less.\033[0m\n"
  exit 1
fi

source "${REPO_DIR}/../common/scripts/aad-helpers.sh"

# Create resource group if needed
echo "Creating resource group if needed..."
az group create --name $RESOURCE_GROUP --location $LOCATION --output table

GROUP_UNIQUE_STR=`az group show --name $RESOURCE_GROUP --query id --output tsv | md5sum | cut -c1-5`

# Get executing user ID
CURRENT_USER_OBJECT_ID=`az ad signed-in-user show --query 'objectId' --output tsv`

# Create the Private Service Principal if it's not set in our shell
if [ -z ${PRIVATE_SP+x} ]; then
  echo "Creating or updating private service principal..."
  PRIVATE_SP=`createServicePrincipal "$PREFIX-private-client-${GROUP_UNIQUE_STR}"`
  echo "PRIVATE_SP=$(echo $PRIVATE_SP | tr -d ' ')" >> "${REPO_DIR}/.env"
fi

# Create the Function Service Principal if it's not set in our shell
if [ -z ${FUNCTION_SP+x} ]; then
  echo "Creating or updating function service principal..."
  FUNCTION_APP_NAME="${PREFIX}-${GROUP_UNIQUE_STR}-func"


  FUNCTION_SP=`createServicePrincipal "$FUNCTION_APP_NAME"`

  addReplyUrl "$FUNCTION_SP" "https://${FUNCTION_APP_NAME}.azurewebsites.net/.auth/login/aad/callback"
  createAppRolesFromWebJson "$FUNCTION_SP" 'https://raw.githubusercontent.com/microsoft/fhir-proxy/main/scripts/fhirroles.json'

  addDefaultIdentifierUri "$FUNCTION_SP" 

  echo "FUNCTION_SP=$(echo $FUNCTION_SP | tr -d ' ')" >> "${REPO_DIR}/.env"
fi

# Create the Public Service Principal if it's not set in our shell
if [ -z ${PUBLIC_SP+x} ]; then
  echo "Creating or updating public service principal..."
  PUBLIC_SP=`createServicePrincipal "$PREFIX-public-client-${GROUP_UNIQUE_STR}"`

  # Give AAD a sec to breathe
  sleep 10

  grantAppPermission "$FUNCTION_SP" "$PUBLIC_SP" "user_impersonation"
  addReplyUrl "$PUBLIC_SP" "https://oauth.pstmn.io/v1/callback"

  FUNCTION_SP_OBJECT_ID=`echo $FUNCTION_SP | jq -r '.enterpriseObjectId'`
  PUBLIC_SP_OBJECT_ID=`echo $PUBLIC_SP | jq -r '.enterpriseObjectId'`
  FHIR_WRITER_ROLE='2d1c681b-71e0-4f12-9040-d0f42884be86'
  FHIR_READER_ROLE='24c50db1-1e11-4273-b6a0-b697f734bcb4'

  echo "Granting FHIR Proxy Client Service Principal access to FHIR Proxy..."
  for APP_ROLE_ID in "$FHIR_WRITER_ROLE" "$FHIR_READER_ROLE"
  do
      grantAppRoleIfNeeded "$FUNCTION_SP_OBJECT_ID" "$PUBLIC_SP_OBJECT_ID" "$APP_ROLE_ID"

      echo "grantAppRoleIfNeeded $FUNCTION_SP_OBJECT_ID $CURRENT_USER_OBJECT_ID $APP_ROLE_ID"
      grantAppRoleIfNeeded "$FUNCTION_SP_OBJECT_ID" "$CURRENT_USER_OBJECT_ID" "$APP_ROLE_ID"
  done

  echo "PUBLIC_SP=$(echo $PUBLIC_SP | tr -d ' ')" >> "${REPO_DIR}/.env"
fi


# Deploy bicep template
echo "Deploying infra via Bicep..."
az deployment group create \
    --name main \
    --resource-group $RESOURCE_GROUP \
    --template-file "${REPO_DIR}/main.bicep" \
    --parameters prefix="$PREFIX" \
    --parameters groupUniqueString="$GROUP_UNIQUE_STR" \
    --parameters adminPrincipalIds="['"$CURRENT_USER_OBJECT_ID"']" \
    --parameters privateServicePrincipal="$PRIVATE_SP" \
    --parameters publicServicePrincipal="$PUBLIC_SP" \
    --parameters functionServicePrincipal="$FUNCTION_SP" \
    --parameters fhirType="$FHIR_TYPE" \
    --output table