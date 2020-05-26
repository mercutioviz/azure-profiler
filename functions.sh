## Cloud Installer Helper Functions

dprint() {
    if [ "$DEBUG" == 'true' ]
    then
        echo "$@" 1>&2
    fi
}

report() {
    if [[ ! -z "$@" ]]; then
	dprint "Report Data: $@"
	echo "$@" >> $TMPFILE
    fi
}

get_selection() {
    if [ -z "$@" ]
    then
        dprint "Call to get_selection function w/o an argument; no selection set"
    else
        #
	PS3="Select an item: "
	#for I in `echo "$@"`; do echo $I; done
	
        OIFS=$IFS
	IFS=$'\n'
	dprint "Args: $@"
	select my_selection in `echo "$@"`;
        do
	    echo $REPLY
            echo "You chose '${my_selection}' - press <enter> to accept, any other key select again"
            stty_orig=`stty -g` # save original terminal setting.
            stty -echo          # turn-off echoing.
            read ans            # read the verify action
            stty $stty_orig     # restore terminal setting.
            if [ -z "$ans" ] 
            then
                break 
            else
                echo ""
            fi
        done
	IFS=$OIFS
    fi
}

cloud_cli_available() {
    # return true if CLI stuff is found
    case "$1" in
        Azure|azure|Az|AZ|az)
            # check for Azure CLI
            myaz=`az --version | grep azure-cli`
            if [ ! -z "$myaz" ]
            then
                CLOUD_FOUND="True"
                dprint "Found Azure ($myaz)"
            fi
            ;;
        GCP|gcp)
            # check for GCP CLI
            ;;
        AWS|aws)
            # check for AWS CLI
            ;;
    esac

    return
}

function get_vms() {
    #
    vm_json=`$AZ_CMD vm list --query "[?location=='${location}']"`
    vm_list=`echo "${vm_json}" | jq -r '.[].name'`
    return 0
}

function get_locations() {
    #
    if [[ ! -z "$NORTH_AMERICA" ]]; then
	echo "Getting North America resources only"
	location_json=`$AZ_CMD account list-locations --query "[?contains(displayName,' US')||contains(displayName,'Canada ')]"  2>/dev/null`
    else
	location_json=`$AZ_CMD account list-locations 2>/dev/null`
    fi
    
    location_list=`echo ${location_json} | jq -r '.[].name'`

}

function get_resource_groups() {
    #
    case "$CLOUD" in
    Azure)
        # Get Azure RGs
        rg_json=`$AZ_CMD group list --query "[?location=='${location}']"`
        rg_list=`echo "${rg_json}" | jq -r '.[].name'`
	rg_count=`echo "${rg_json}" | jq -r '. | length'`
	dprint $rg_list
        ;;
    AWS)
        # Get AWS RGs

        ;;
    GCP)
        # Get GCP RGs

        ;;
    (*) break;;
    esac

    return 0
}

function get_vnets() {
    #
    vnet_json=`$AZ_CMD network vnet list --query "[?location=='${location}']"`
    dprint "VNet JSON data: ${vnet_json}"
    vnet_list=`echo "${vnet_json}" | jq -r '.[] | .name'`
    dprint "VNet list: ${vnet_list}"
    vnet_count=`echo "${vnet_json}" | jq -r '. | length'`
    
    return 0
}

function get_pips() {
    #
    return 0
}

function get_lbs() {
    #
    return 0
}

function get_route_tables() {
    #
    return 0
}

function get_routes() {
    #
    return 0
}

function get_available_cpus() {
    # How many vCPUs available to deploy in this region
    return 1
}

function get_regions() {
    #
    return 0
}
