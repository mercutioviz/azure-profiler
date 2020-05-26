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
if ! options=$(getopt -o hdvcnr:p:l: \
        -l help,debug,verbose,current-sub,north-america,rg:,password:,location: \
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
    -c|--current-sub) CURRENT_SUB="true" ;;
    -n|--north-america) NORTH_AMERICA="false" ;;
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

echo "Getting account info..."
current_sub=`$AZ_CMD account show 2>/dev/null`
echo

TMPFILE=`mktemp`
dprint "Debug on..."
dprint "Tempfile file is $TMPFILE"
az_subs=`$AZ_CMD account list 2>/dev/null`
dprint "${az_subs}" | jq '.'
az_sub_count=`echo "${az_subs}" | jq '. | length'`
dprint "Found ${az_sub_count} sub(s)"

if [[ "${az_sub_count}" -eq 1 ]]; then
    sub_name=`echo "${az_subs}" | jq -r '.[0] | .name'`
    dprint "Found 1 sub: ${sub_name}"
elif [[ ! -z "$CURRENT_SUB" ]]; then
    sub_id=`echo "${current_sub}" | jq -r '.id'`
    sub_name=`echo "${current_sub}" | jq -r ".name"`    
    echo "Using current default subscription ${sub_id} ($sub_name)"
elif [[ "${az_sub_count}" -gt 1 ]]; then
    ## Multiple subs, select one first
    echo "Choose a sub..."
    az_sub_list=`echo ${az_subs} | jq -r '.[] | [.id,.name] | @csv'`
    dprint "Azure sub list is: '$az_sub_list'"
    get_selection "$az_sub_list"
    dprint "Selection / REPLY : '$my_selection' / '$REPLY'"
    
    ## Assign name and id
    if [[ $REPLY -ge 1 ]]; then
	sub_idx=$(($REPLY-1))
    else
	sub_idx=0
    fi

    current_sub_id=`echo "${current_sub}" | jq -r '.id'`
    sub_id=`echo "${az_subs}" | jq -r ".[${sub_idx}].id"`
    sub_name=`echo "${az_subs}" | jq -r ".[${sub_idx}].name"`
    echo "Found subscription '${sub_name}' (${sub_id})"
    echo "Profile operation continuing..."
    $AZ_CMD account set -s ${sub_id} 2>/dev/null
    echo -n "Azure account set to "
    $AZ_CMD account show 2>/dev/null | jq '.id'
    echo

else
    ## Something went wrong...
    exit 1
fi

get_locations
if [[ -z "${DEPLOY_LOCATION}" ]]; then
    ## enumerate locations for this sub
    report "--==  Profile report for multiple locations for subscription ${sub_name} ==--"
    for location in `echo "${location_list}"`; do
        echo "Processing ${location}..."
	location_name=`echo "${location_json}" |jp "[?name=='${location}']" | jq -r '.[].displayName'`
	get_resource_groups
	if [[ "$rg_count" -ge 1 ]]; then
	    ## Skip unless we actually have RGs
	    report
	    report "--== Location: ${location_name} ==--"
	    report "Resource Groups:"
	    for I in $rg_list; do report "  $I"; done
	    get_vnets
	    report "Virtual Networks:"
	    for I in $vnet_list; do report "  $I"; done
	    get_vms
	    report "Virtual Machines:"
	    for I in $vm_list; do report "  $I"; done
	fi
    done
    report
else
    ## use location supplied via arg
    location=`echo "${DEPLOY_LOCATION}" | sed -e "s/'//g"`
    echo -n "Location: ${location}"
    location_name=`echo "${location_json}" |jp "[?name=='${location}']" | jq -r '.[].displayName'`
    echo " (${location_name})"
    get_resource_groups
    get_vnets
    get_vms

    report "Report for subscription ${sub_name}"
    report " and location ${location_name}"
    report "============================================================"
    report "Resource Groups:"
    for I in $rg_list; do report "  $I"; done
    report
    report "Virtual Networks:"
    for I in $vnet_list; do report "  $I"; done
    report
    report "Virtual Machines:"
    for I in $vm_list; do report "  $I"; done
    report
    
fi
echo
echo
cat $TMPFILE
echo
rm -f $TMPFILE
if [[ ! -z "${current_sub_id}" ]]; then
    res=`$AZ_CMD account set -s ${current_sub_id} 2>/dev/null`
fi
