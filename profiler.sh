#!/bin/bash
. ./functions.sh

echo "
#
#  Azure profiler
#
"

# Stop running when command returns error
set -e
CLOUD='Azure'
AZ_CMD=`which az`
if [[ -z "${AZ_CMD}" ]]; then
    echo "Azure CLI command not found. Install Azure CLI. See xxx for details."
    exit 1
fi

# Process arguments
if ! options=$(getopt -o hdvr:p:l: \
        -l help,debug,verbose,rg:,password:,location: \
        -- "$@") #"
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi

set -- $options

while [ $# -gt 0 ]
do
    case $1 in
    -h|--help) 
                echo "Azure profiler" 
                exit 0
                ;;
    -d|--debug) DEBUG='true' ;;
    -v|--verbose) DEBUG='true' ;;
    # for options with required arguments, an additional shift is required
    -r|--rg) RESOURCE_GROUP="$2" ; shift;;
    -l|--location) DEPLOY_LOCATION="$2" ; shift;;
    -p|--password) DEPLOY_PASSWORD="$2" ; shift;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
    esac
    shift
done

dprint "Debug on..."

az_subs=`az account list`
dprint "${az_subs}" | jq '.'
az_sub_count=`echo "${az_subs}" | jq '. | length'`
dprint "Found ${az_sub_count} sub(s)"

if [[ "${az_sub_count}" -eq 1 ]]; then
    sub_name=`echo "${az_subs}" | jq -r '.[0] | .name'`
    dprint "Found 1 sub: ${sub_name}"
elif [[ "${az_sub_count}" -gt 1 ]]; then
    ## Multiple subs, select one first
    echo "Choose a sub..."
else
    ## Something went wrong...
    exit 1
fi

echo "Found subscription '${sub_name}'"
echo "Profile operation continuing..."

if [[ -z "${DEPLOY_LOCATION}" ]]; then
    ## enumerate locations for this sub
    get_locations
    for location in `echo "${location_list}"`; do
        echo "Processing '${location}'..."
    done
else
    ## use location supplied via arg
    location="${DEPLOY_LOCATION}"
    echo "Location: ${location}"
    get_resource_groups
    get_vnets
fi
