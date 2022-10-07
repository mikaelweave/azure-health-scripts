#!/usr/bin/env bash
set -euo pipefail

# Creates service principal and sets variables to informatino aboiut service principal
# $1 name of the service principal to create
function createServicePrincipal()
{
    SP=`az ad sp create-for-rbac --name $1 --only-show-errors --output json`
    APP_ID=`echo $SP | jq -r '.appId'`
    ID=`az ad app show --id $APP_ID --query "id" --out tsv`
    ENTERPRISE_ID=`az ad sp show --id $APP_ID --query "id" --out tsv`

    echo $SP | jq --arg id $ID '. + {id: $id}' | jq --arg id $ENTERPRISE_ID '. + {enterpriseId: $id}'
}


# Grants specified app role on an AAD application to a specified principal
# $1 JSON of App to add roles to
# Path of JSON file with roles
function createAppRolesFromPathJson()
{
    SP_APP_ID=`echo $1 | jq -r '.appId'`
    az ad app update --id $SP_APP_ID --app-roles @"$2"
}


# Checks to see if app role is already assigned
function checkAppRoleAssignment()
{
    APP_ROLE_ASSIGNMENTS=$(az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignedTo")

    echo `echo $APP_ROLE_ASSIGNMENTS | \
        jq -r --arg APP_ROLE_ID "$3" --arg PUBLIC_SP_ID "$2" \
            '.value[] | select(.appRoleId==$APP_ROLE_ID and .principalId==$PUBLIC_SP_ID)'` \
        | wc -c

    return
}


# Grants specified app role on an AAD application to a specified principal
# $1 Id of the App access is being granted to
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
# $1 Id of the App access is being granted to
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
# $1 App Id
# $2 Reply URL
function addReplyUrl()
{
    az ad app update --id `echo $1 | jq -r '.appId'` --public-client-redirect-uris "$2"
}


# Grants a specified AAD permission of one app to another
# $1 - App with permissions
# $2 - App to be given permission
# $3 - Permission name
function grantAppPermission()
{
  SP_ID=`echo $1 | jq -r '.id'` 
  PERMISSION_ID=`az rest --method get --uri "https://graph.microsoft.com/beta/applications/${SP_ID}" --query "api.oauth2PermissionScopes[?value=='$3'].id" --output tsv`

  GIVEN_SP_APP_ID=`echo $2 | jq -r '.appId'`

  az rest --method patch --uri "https://graph.microsoft.com/beta/applications/${SP_ID}" \
      --headers '{"Content-Type":"application/json"}' \
      --body '{"api":{"preAuthorizedApplications":[{"appId":"'"$GIVEN_SP_APP_ID"'","permissionIds":["'"$PERMISSION_ID"'"]}]}}'
}

# Sets the default identifier uri in the "api://guid format"
function addDefaultIdentifierUri()
{
    APP_ID=`echo $1 | jq -r '.appId'`
    az ad app update --id "$APP_ID" --identifier-uris "api://${APP_ID}"
}