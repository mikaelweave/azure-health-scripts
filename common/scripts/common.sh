#!/usr/bin/env bash
set -euo pipefail

# $1 - Path to project root with .env file to load
function startup()
{

    # Ensure jq is installed
    if ! command -v jq &> /dev/null
    then
        printf "\033[0;31m jq could not be found. jq must be installed for this script.\033[0m\n"
        exit 1
    fi

    # Load from .env file from projec root from cli
    if [ -f "${1}/.env" ]
    then
    set -a
    export $(cat "${1}/.env" | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" | xargs)
    set +a
    fi

    # Ensure the azure cli is logged in
    if ! az account show &> /dev/null
    then
        echo -e "\033[0;31m You must login to the azure cli before running this script.\033[0m\n"
        exit 1
    fi

    # Ensure azure function core tools is installed
    if ! command -v func &> /dev/null
    then
        printf "\033[0;31m func could not be found. Azure Function tools must be installed for this script.\033[0m\n"
        exit 1
    fi
}
