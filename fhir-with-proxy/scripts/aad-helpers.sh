#!/usr/bin/env bash
set -euo pipefail

# Find the path on the system of the script and repo
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR="${SCRIPT_DIR}/.."

# Creates service principal and sets variables to informatino aboiut service principal
# $1 name of the service principal to create
function createServicePrincipal()
{
    SP=`az ad sp create-for-rbac --name $1 --only-show-errors --output json`
    APP_ID=`echo $SP | jq -r '.appId'`
    OBJECT_ID=`az ad app show --id $APP_ID --query "objectId" --out tsv`
    ENTERPRISE_OBJECT_ID=`az ad sp show --id $APP_ID --query "objectId" --out tsv`

    echo $SP | jq --arg objectId $OBJECT_ID '. + {objectId: $objectId}' | jq --arg objectId $ENTERPRISE_OBJECT_ID '. + {enterpriseObjectId: $objectId}'
}


# Grants specified app role on an AAD application to a specified principal
# $1 JSON of App to add roles to
# URL of JSON file with roles
function createAppRolesFromWebJson()
{
    SP_APP_ID=`echo $1 | jq -r '.appId'`

    mkdir -p "${REPO_DIR}/tmp" >/dev/null 2>&1
    curl -L -Z "$2" --output "${REPO_DIR}/tmp/fhirroles.json"
    az ad app update --id $SP_APP_ID --app-roles @"${REPO_DIR}/tmp/fhirroles.json"
}


# Checks to see if app role is already assigned
function checkAppRoleAssignment()
{
    APP_ROLE_ASSIGNMENTS=$(az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignedTo")

    echo `echo $APP_ROLE_ASSIGNMENTS | \
        jq -r --arg APP_ROLE_ID "$3" --arg PUBLIC_SP_OBJECT_ID "$2" \
            '.value[] | select(.appRoleId==$APP_ROLE_ID and .principalId==$PUBLIC_SP_OBJECT_ID)'` \
        | wc -c

    return
}


# Grants specified app role on an AAD application to a specified principal
# $1 ObjectId of the App access is being granted to
# $2 PrincipalID of the user, group, or service principal access is granted to
# $3 App Role ID
function grantAppRole()
{
    az rest --method POST \
        --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments" \
        --headers '{"Content-Type":"application/json"}' \
        --body "{\"principalId\": \"$2\", \"resourceId\": \"$1\", \"appRoleId\": \"$3\"}"
}


# Grants specified app role on an AAD application to a specified principal
# $1 ObjectId of the App access is being granted to
# $2 PrincipalID of the user, group, or service principal access is granted to
# $3 App Role ID
function grantAppRoleIfNeeded()
{
    if [[ `checkAppRoleAssignment "$1" "$2" "$3"` -lt 4 ]]
    then
        echo "Granting role ${3}..."
        grantAppRole "$1" "$2" "$3"
    fi
}

# Adds a reply URL to an App
# $1 App Object
# $2 Reply URL
function addReplyUrl()
{
    az ad app update --id `echo $1 | jq -r '.appId'` --reply-urls "$2"
}


# Grants a specified AAD permission of one app to another
# $1 - App with permissions
# $2 - App to be given permission
# $3 - Permission name
function grantAppPermission()
{

  SP_OBJECT_ID=`echo $1 | jq -r '.objectId'` 
  PERMISSION_ID=`az rest --method get --uri "https://graph.microsoft.com/beta/applications/${SP_OBJECT_ID}" --query "api.oauth2PermissionScopes[?value=='$3'].id" --output tsv`

  GIVEN_SP_APP_ID=`echo $2 | jq -r '.appId'`

  az rest --method patch --uri "https://graph.microsoft.com/beta/applications/${SP_OBJECT_ID}" \
      --headers '{"Content-Type":"application/json"}' \
      --body '{"api":{"preAuthorizedApplications":[{"appId":"'"$GIVEN_SP_APP_ID"'","permissionIds":["'"$PERMISSION_ID"'"]}]}}'
}