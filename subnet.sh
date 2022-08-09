#!/usr/bin/env bash
version="0.8"
dependencies=("cat" "grep" "sed" "awk" "wc" "seq" "cut" "tr" "rev" "column" "echo" "printf" "head" "rm")

# Text colors
red="\033[1;31m"
green="\033[1;32m"
default="\033[0m"

#########################
# Text output functions #
#########################

print_green() { # Print green text
	printf "${green}%s${default}\n" "${*}"
}

print_red() { # Print red text to STDERR
	printf "${red}%s${default}\n" "${*}" >&2
}

#######################
# Auxiliary functions #
#######################

show_help() {
	while IFS= read -r line
    do
		printf "%s\n" "${line}"
	done <<-EOF

	Subnet Calculator v.${version}
	Bash script to assist subnetting process
	Usage: subnet [options]

	Options:
        --help              Print this help page
        -m, --mode          Change mode of the script to run
        -i, --ip            Provide the IP address
        -c, --cidr          Provide the CIDR
        -n, --netmask       Provide the Netmask
        -s, --subnets       Expected number of subnets
        -h, --hosts         Expected number of available hosts per subnet
        -t, --try           Number of subnets' detail to print

	Modes:
        1 - Get network information from a pair of IP address and its CIDR notation e.g. 10.0.0.0/16
        2 - Perform subnet calculation for for the amount of required hosts per subnet or required subnets
        3 - Check the type and class of an IP address
	EOF
}

check_dependencies() {
	for dependency in "${dependencies[@]}"
    do
		if ! command -v "${dependency}" &> /dev/null
        then
			print_red "Missing dependency: '${dependency}'"
            exit_script=true
		fi
	done

	if [[ "${exit_script}" == "true" ]]
    then
		exit 1
	fi
}

####################
# Parser functions #
####################

# Join a list of binary numbers by removing whitespaces
# Example: 1111 1110 1101 1100 > 1111111011011100
join_binary() {
    IFS=""
    printf "%s" "${*}"
}

# Join a list of octets into an IP address
# Example: 123 45 67 89 > 123.45.67.89
join_octet() {
    IFS="."
    printf "%s" "${*}"
}

# Split an IP address into a list of octets
# Example: 123.45.67.89 > 123 45 67 89
split_octet() {
    IFS=. read -ra octet_list <<< "${1}"
    test_octet=()

    # check if any octet is greater than 255
    for x in "${!octet_list[@]}"
    do
        [[ "${octet_list[${x}]}" -gt 255 ]] &&
        break ||
        test_octet+=(1)
    done

    # only valid octet list can pass this
    [[ "${#octet_list[@]}" -eq 4 ]] && 
    [[ "${#test_octet[@]}" -eq 4 ]] &&
    printf "%s\n" "${octet_list[@]}" &&
    return 0 ||
    print_red "Invalid input: '${1}'" &&    
    return 1
}


#######################
# Converter functions #
#######################

# Convert Netmask to CIDR notation
# Example: 255.255.255.0 > 24
netmask_to_cidr() {
    netmask_to_convert="${1}"
    mapfile -t netmask_list < <(split_octet "${netmask_to_convert}")
    
    netmask_binary=""
    for x in "${netmask_list[@]}"
    do
        quotient="$((x / 2))"
        remainder="$((x % 2))"
        remainder_array=()
        remainder_array+=("${remainder}")

        until [[ "${quotient}" -eq 0 ]]
        do
            x="${quotient}"
            quotient="$((x / 2))"
            remainder="$((x % 2))"
            remainder_array+=("${remainder}")
        done

        netmask_child_binary="$(printf "%s" "${remainder_array[@]}" | rev)" # reverse the binary result
        netmask_child_binary="$(printf "%08d" "${netmask_child_binary}")" # add 0s to make it 8 bits
        netmask_binary+="${netmask_child_binary}"
    done
    
    # count all 1s and use it as cidr
    cidr_result="$(
        printf "%s" "${netmask_binary}" |
        grep -aob 0 |
        head -n1 |
        cut -d: -f1
    )"

    [[ -z "$cidr_result" ]] && cidr_result="32"

    printf "%s" "${cidr_result}"
    return 0
}

# Convert CIDR notation to Netmask address
# Example: 24 > 255.255.255.0
cidr_to_netmask() {
    cidr_to_convert="${1}"
    full_octet="11111111"
    zero_octet="00000000"

    if [[ "${cidr_to_convert}" -le 8 ]]
	then
        # process the first octet for conversion
        hosts="$((8 - cidr_to_convert))"
        network_bits="$(
			for i in $(seq "${cidr_to_convert}")
			do
				printf "1"
			done
		)"
        host_bits="$(
			for i in $(seq "${hosts}")
			do
				printf "0"
			done
		)"
        netmask_octet="${network_bits}${host_bits}"
        netmask_binary_list=(
			"${netmask_octet}"
			"${zero_octet}"
			"${zero_octet}"
			"${zero_octet}"
		)
    elif [[ "${cidr_to_convert}" -gt 8 ]] && 
		 [[ "${cidr_to_convert}" -le 16 ]]
	then
        # process the second octet for conversion
        cidr_to_convert="$((cidr_to_convert - 8))"
        hosts="$((8 - cidr_to_convert))"
        network_bits="$(
			for i in $(seq "${cidr_to_convert}")
			do
				printf "1"
			done
		)"
        host_bits="$(
			for i in $(seq "${hosts}")
			do
				printf "0"
			done
		)"
        netmask_octet="${network_bits}${host_bits}"
		netmask_binary_list=(
			"${full_octet}"
			"${netmask_octet}"
			"${zero_octet}"
			"${zero_octet}"
		)
    elif [[ "${cidr_to_convert}" -gt 16 ]] &&
		 [[ "${cidr_to_convert}" -le 24 ]]
	then
        # process the third octet for conversion
        cidr_to_convert="$((cidr_to_convert - 16))"
        hosts="$((8 - cidr_to_convert))"
		network_bits="$(
			for i in $(seq "${cidr_to_convert}")
			do
				printf "1"
			done
		)"
        host_bits="$(
			for i in $(seq "${hosts}")
			do
				printf "0"
			done
		)"
        netmask_octet="${network_bits}${host_bits}"
		netmask_binary_list=(
			"${full_octet}"
			"${full_octet}"
			"${netmask_octet}"
			"${zero_octet}"
		)
    elif [[ "${cidr_to_convert}" -gt 24 ]] &&
		 [[ "${cidr_to_convert}" -le 32 ]]
	then
        # process the fourth octet for conversion
        cidr_to_convert="$((cidr_to_convert - 24))"
        hosts="$((8 - cidr_to_convert))"
		network_bits="$(
			for i in $(seq "${cidr_to_convert}")
			do
				printf "1"
			done
		)"
        host_bits="$(
			for i in $(seq "${hosts}")
			do
				printf "0"
			done
		)"
        netmask_octet="${network_bits}${host_bits}"
		netmask_binary_list=(
			"${full_octet}"
			"${full_octet}"
			"${full_octet}"
			"${netmask_octet}"
		)
	else
		print_red "Invalid input: '${1}'"
		return 1
    fi

    for x in ${!netmask_binary_list[@]}
    do
        netmask_binary_list[$x]="$((2#"${netmask_binary_list[$x]}"))"
    done

    join_octet "${netmask_binary_list[@]}"
	return 0
}

# Convert an IP address to binary list
# Example: 172.12.34.56 > 10101100 00100010 00111000 01001110
ip_to_binary_list() {
    ip_to_convert="${1}"
    mapfile -t ip_list < <(split_octet "${ip_to_convert}")

    ip_binary_list=()
    for x in "${ip_list[@]}"
    do
        quotient="$((x / 2))"
        remainder="$((x % 2))"
        remainder_array=()
        remainder_array+=("${remainder}")

        until [[ "${quotient}" -eq 0 ]]
        do
            x="${quotient}"
            quotient="$((x / 2))"
            remainder="$((x % 2))"
            remainder_array+=("${remainder}")
        done

        ip_child_binary="$(printf "%s" "${remainder_array[@]}" | rev)" # reverse the binary result
        ip_child_binary="$(printf "%08d" "${ip_child_binary}")" # add 0s to make it 8 bits
        ip_binary_list+=("${ip_child_binary}")
    done

    printf "%s\n" "${ip_binary_list[@]}"
    return 0
}

# Convert a binary list to an IP address
# Example: 10101100 00100010 00111000 01001110 > 172.12.34.56
binary_list_to_ip() {
    binary_list_to_convert=("$@")

    for x in "${!binary_list_to_convert[@]}"
    do
        binary_list_to_convert[$x]="$((2#"${binary_list_to_convert[$x]}"))"
    done

    join_octet "${binary_list_to_convert[@]}"
	return 0
}

####################
# Mode 1 functions #
####################

# Get the information of a pair of IP address and its CIDR notation e.g. 10.0.0.0/16
inspect_ip_address() {
    ip_to_inspect="${1}"
    cidr_to_inspect="${2}"

    octet_list=($(split_octet "${ip_to_inspect}"))
	if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${octet_list}"
		return 1
	fi

    netmask="$(cidr_to_netmask "${cidr_to_inspect}")"
	if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${netmask}"
		return 1
	fi

    netmask_binary_list=($(ip_to_binary_list "${netmask}"))
	if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${netmask_binary_list}"
		return 1
	fi

    for x in "${!octet_list[@]}"
    do
        octet_list[$x]="$(("${octet_list[$x]}" & 2#"${netmask_binary_list[$x]}"))"
    done

    if [[ "${cidr_to_inspect}" -lt 31 ]]
	then
        network_address="$(join_octet "${octet_list[@]}")"
        first_available_ip="$(join_octet "${octet_list[0]}" "${octet_list[1]}" "${octet_list[2]}" "$(("${octet_list[3]}" + 1))")"
        total_available_hosts="$((2 ** (32 - "${cidr_to_inspect}") - 2))"
        wildcard_mask_list=($(wildcard_mask_list "${netmask}"))
        broadcast_address="$(
			for x in ${!wildcard_mask_list[@]}
			do
				list+=($(("${octet_list[$x]}" + (2#"${wildcard_mask_list[$x]}"))))
			done
			join_octet "${list[@]}"
		)" 
        last_ip_octet_list=($(split_octet "${broadcast_address}"))
        last_ip_octet_list[3]="$(("${last_ip_octet_list[3]}" - 1))"
        last_available_ip="$(join_octet "${last_ip_octet_list[@]}")"
    elif [[ "${cidr_to_inspect}" -eq 31 ]]
	then
        network_address="-"
        first_available_ip="$(join_octet "${octet_list[@]}")"
        total_available_hosts="2"
        broadcast_address="${network_address}"
        last_available_ip="$(join_octet "${octet_list[0]}" "${octet_list[1]}" "${octet_list[2]}" "$((${octet_list[3]} + 1))")"
    else
        network_address="-"
        first_available_ip="$(join_octet "${octet_list[@]}")"
        total_available_hosts="1"
        broadcast_address="${network_address}"
        last_available_ip="${first_available_ip}"
    fi
    
    printf "%s" "${network_address},${cidr_to_inspect},${netmask},${total_available_hosts},${first_available_ip} - ${last_available_ip},${broadcast_address}"
    return 0
}

# Get complementary netmask list for inspect_ip_address function
wildcard_mask_list() {
    netmask_to_complement="${1}"
    wildcard_mask_list=($(ip_to_binary_list "$netmask_to_complement"))

	if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${wildcard_mask_list}"
		return 1
	else
		for x in ${!wildcard_mask_list[@]}
		do
			wildcard_mask_list[$x]="$(printf "%s" "${wildcard_mask_list[x]}" | tr 01 10)"
		done

		printf "%s" "${wildcard_mask_list[*]}"
		return 1
	fi
}

####################
# Mode 2 functions #
####################

# Perform subnet calculation for the given network address block
subnet_calculator() {
    ip_address="${1}"
    [[ "${2}" =~ "host" ]] && host_amount="${3}" || subnet_amount="${3}"
    if [[ "${4}" =~ ^-?[0-9]+$ ]]
	then
        sample_amount="${4}"
    elif [[ -z "${4}" ]] ||
         [[ "${4}" != "all" ]]
	then
        sample_amount="2"
    fi
    declare -A default_network_bits
    default_network_bits[A]="8"
    default_network_bits[B]="16"
    default_network_bits[C]="24"

    ip_class="$(ip_class "${ip_address}")"
    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${ip_class}"
		return 1
    elif [[ -z "${default_network_bits["${ip_class}"]}" ]]
    then
        print_red "IP class '${ip_class}' is not allowed for subnetting"
        return 1
    fi

    default_cidr="${default_network_bits["${ip_class}"]}"
    default_network="$(inspect_ip_address "${ip_address}" "${default_cidr}")"
    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${default_network}"
		return 1
	fi

    default_network_address="$(printf "%s" "${default_network}" | cut -d',' -f1)"
    default_network_address_binary_list=($(ip_to_binary_list "${default_network_address}"))
    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${default_network_address_binary_list[*]}"
		return 1
	fi

    default_network_address_binary="$(join_binary "${default_network_address_binary_list[@]}")"
    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${default_network_address_binary}"
		return 1
	fi
    
    subnet_details_list=() # array to store network address of each subnet

    # Data to perform subnet calculation for the amount of required hosts per subnet
    if [[ "${host_amount}" ]]
    then
        cidr="$(host_bits_prefix "${host_amount}")" # this will be the cidr notation for the subnet
        if [[ "${?}" -ne 0 ]]
        then
            printf "%s" "${cidr}"
            return 1
        fi

        subnet_bits="$((cidr - default_cidr))"
        useable_ip_amount="$((2 ** (32 - cidr) - 2))" # amount of usable ip address in each subnet
        if [[ "${useable_ip_amount}" -le "0" ]]
        then
            print_red "No effective host for subnet with network bits of '${cidr}'"
            return 1
        fi
    fi

    # Data to perform subnet calculation for the amount of required subnets
    if [[ "${subnet_amount}" ]]
    then
        for x in $(seq 0 23)
        do
            if [[ "$((2 ** x))" -ge "${subnet_amount}" ]]
            then
                subnet_bits="${x}"
                break
            fi
        done

        cidr="$((subnet_bits + default_cidr))" # this will be the cidr notation for the subnet
        useable_ip_amount="$((2 ** (32 - cidr) - 2))" # amount of usable ip address in each subnet
        if [[ "${useable_ip_amount}" -eq "0" ]]
        then
            print_red "No effective hosts for subnet with network bits of '${cidr}'"
            return 1
        fi
    fi

    # Perform subnet calculation with the generated data
    if [[ "${subnet_bits}" -gt 0 ]]
        then
            flag="subnet"
            subnet_amount="$((2 ** subnet_bits))"
            total_hosts="$((useable_ip_amount * subnet_amount))"
            subnet_binary_list=($(subnet_binary_list "${subnet_bits}" "${sample_amount}"))
            for x in ${!subnet_binary_list[@]}
            do
                subnet_binary_start="${default_network_address_binary::${default_cidr}}"
                subnet_binary_middle="${subnet_binary_list["${x}"]}"
                subnet_binary_end="$(printf "%0$((32 - cidr))d")"

                subnet_full_binary="${subnet_binary_start}${subnet_binary_middle}${subnet_binary_end}"
                binary_list=(
                    "${subnet_full_binary:0:8}"
                    "${subnet_full_binary:8:8}"
                    "${subnet_full_binary:16:8}"
                    "${subnet_full_binary:24:8}"
                )
                subnet_details_list+=("$(binary_list_to_ip "${binary_list[@]}")")
            done
        else
            flag="supernet"
            subnet_amount="1"
            network_information="$(inspect_ip_address "${ip_address}" "${cidr}")"
            if [[ "${?}" -ne 0 ]]
            then
                printf "%s" "${network_information}"
                return 1
            fi

            network_address="$(printf "%s" "${network_information}" | cut -d',' -f1)"
            subnet_details_list+=("$network_address")
        fi

        printf "%s" "${cidr},${ip_class},${flag},${subnet_amount},${total_hosts},${subnet_details_list[*]}"
        return 0
}

# Get prefix or cidr notation from expected amount of host per subnet
host_bits_prefix() {
    host_amount="${1}"

    if [[ "${host_amount}" -eq 0 ]]
    then
        prefix="32"
    elif [[ "${host_amount}" -eq 1 ]]
    then
        prefix="31"
    else
        for x in $(seq 0 24)
        do
            if [[ "$((2 ** x - 2))" -ge "${host_amount}" ]]
            then
                prefix="$((32 - x))"
                break
            fi
        done
    fi

    if [[ -n "${prefix}" ]]
    then
        printf "%s" "${prefix}"
        return 0
    else
        print_red "Invalid host amount: '${1}'"
        return 1
    fi
}

# Generate a list of binary number for a subnet block
subnet_binary_list() {
    bits_to_convert="${1}"
    stop_position="${2}"

    binary_list=()
    for x in $(seq 0 $((2 ** bits_to_convert - 1)))
    do
        current_position="${x}"
        quotient="$((x / 2))"
        remainder="$((x % 2))"
        remainder_array=()
        remainder_array+="${remainder}"

        until [[ "${quotient}" -eq 0 ]]
        do
            x="${quotient}"
            quotient="$((x / 2))"
            remainder="$((x % 2))"
            remainder_array+="${remainder}"
        done

        binary="$(printf "%s" "${remainder_array[@]}" | rev)"	    # reverse the binary result
        binary="$(printf "%0${bits_to_convert}d" "${binary}")"	# add 0s to make it equal to initial bits amount
        binary_list+=("${binary}")
        if [[ "${stop_position}" =~ ^-?[0-9]+$ ]] &&
           [[ "$((current_position + 1))" -ge "${stop_position}" ]]
        then
            break
        fi
    done

    printf "%s" "${binary_list[*]}"
    return 0
}

####################
# Mode 3 functions #
####################

# Check the type of an IP address
ip_type() {
    ip_to_check="${1}"
    ip_class=$(ip_class "${ip_to_check}")

    octet_list=($(split_octet "${ip_to_check}"))
    first_octet="${octet_list[0]}"
    second_octet="${octet_list[1]}"

    case "${ip_class}" in
    A)
        declare -A class_a_dictionary
        class_a_dictionary[10]="Private"
        class_a_dictionary[127]="Loopback"

        if [[ "${!class_a_dictionary[@]}" =~ "${first_octet}" ]]
        then
            ip_type="${class_a_dictionary["${first_octet}"]}"
        else
            ip_type="Public"
        fi
        ;;
    B)
        if [[ "${first_octet}" -eq 172 ]] &&
           [[ "${second_octet}" -ge 16 && "${second_octet}" -le 31 ]]
        then
            ip_type="Private"
        else
            ip_type="Public"
        fi
        ;;
    C)
        if [[ "${first_octet}" -eq 192 ]] &&
           [[ "${second_octet}" -eq 168 ]]
        then
            ip_type="Private"
        else
            ip_type="Public"
        fi
        ;;
    D)
        ip_type="Multicasting"
        ;;
    E)
        ip_type="Research/Reserved/Experimental"
        ;;
    esac

    printf "%s" "${ip_to_check},${ip_class},${ip_type}"
    return 0
}

# Check the class of an IP address
ip_class() {
    ip_to_check="${1}"

    declare -A class_dictionary
    class_dictionary[0]="A"
    class_dictionary[128]="B"
    class_dictionary[192]="C"
    class_dictionary[224]="D"
    class_dictionary[240]="E"

    octet_list=($(split_octet "${ip_to_check}"))
    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${octet_list}"
		return 1
	fi

    first_octet="$(printf "%s" "${octet_list[*]}" | cut -d' ' -f1)"
    flags=()
    for x in "${!class_dictionary[@]}"
    do
        if [[ $((first_octet & x)) -eq "${x}" ]]
        then
            flags+=("${x}")
        fi
    done

    max_flag="$(printf "%s\n" "${flags[@]}" | sort -nr | head -n1)"
    printf "%s" "${class_dictionary["${max_flag}"]}"
    return 0
}

####################
# Render functions #
####################

printTable () {
    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                # Add Header Or Body

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

removeEmptyLines () {
    local -r content="${1}"

    echo -e "${content}" | sed '/^\s*$/d'
}

repeatString () {
    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

isEmptyString () {
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

trimString () {
    local -r string="${1}"

    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

################
# Main scripts #
################

# Check for any missing dependencies
check_dependencies

# Parse option and value
for i in "$@"
do
    case $i in
    -m=*|--mode=*)
        mode="${i#*=}"
        shift
        ;;
    -i=*|--ip=*)
        inputted_ip_address="${i#*=}"
        shift
        ;;
    -c=*|--cidr=*)
        inputted_cidr="${i#*=}"
        shift
        ;;
    -n=*|--netmask=*)
        inputted_netmask="${i#*=}"
        shift
        ;;
    -s=*|--subnets=*)
        inputted_subnet_amount="${i#*=}"
        shift
        ;;
    -h=*|--hosts=*)
        inputted_host_amount="${i#*=}"
        shift
        ;;
    -t=*|--try=*)
        inputted_sample_amount="${i#*=}"
        shift
        ;;
    --help)
        show_help
        exit 1
        ;;
    -*|--*)
        print_red "Unknown option: '${i}'"
        exit 1
        ;;
    esac
done

# Parse the requested mode and execute respected mode's function
case $mode in
1)
    [[ -z "${inputted_ip_address}" || -z "${inputted_cidr}" ]] && # Exit and print examples if either variables are empty
    print_red "Mode usage example: subnet -m=1 -i=192.168.141.111 -c=28" &&
    exit 1 ||
    if ! result="$(inspect_ip_address "${inputted_ip_address}" "${inputted_cidr}")" # Try to get result with those variables
	then # Exit if any variables are not valid, else print the result
        printf "%s" "${result}"
		exit 1
    else
        header="Network Address,CIDR Notation,Subnet Mask,Useable Host/Subnet,Host Address Range,Broadcast Address\n"
        printf "%s\n" "${header}" "${result}" >> "./tmp-data"
        printTable ","  "$(cat ./tmp-data)" && rm "./tmp-data"
        exit 0
    fi
    ;;
2)
    if [[ -z "${inputted_ip_address}" ]] ||
       [[ -z "${inputted_host_amount}" && -z "${inputted_subnet_amount}" ]]
    then
        print_red "Mode usage example:"
        print_red "subnet -m=2 -i=192.168.141.0 -s=2"
        print_red "subnet -m=2 -i=192.168.141.0 -h=50 -t=all"
        exit 1
    fi

    ip_validation="$(split_octet "${inputted_ip_address}")"
    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${ip_validation}"
		exit 1
	fi

    if [[ "${inputted_host_amount}" ]]
    then
        result="$(subnet_calculator "${inputted_ip_address}" "host" "${inputted_host_amount}" "${inputted_sample_amount}")"
    elif [[ "${inputted_subnet_amount}" ]]
    then
        result="$(subnet_calculator "${inputted_ip_address}" "subnet" "${inputted_subnet_amount}" "${inputted_sample_amount}")"
    fi

    if [[ "${?}" -ne 0 ]]
	then
		printf "%s" "${result}"
		exit 1
	fi

    subnet_header="CIDR,IP Class,Type,Subnet Amount,Total Available Hosts,Network Address List"
    subnet_result="$(printf "%s" "${result}" | cut -d',' -f1-5),See below"
    subnet_amount="$(printf "%s" "${result}" | cut -d',' -f4)"
    printf "%s\n" "${subnet_header}" "${subnet_result}" >> "./tmp-data"

    details_header="Subnet ID,Network Address,CIDR Notation,Subnet Mask,Useable Host/Subnet,Host Address Range,Broadcast Address\n"
    printf "%s" "${details_header}" >> "./tmp-network-data"
    
    details_cidr="$(printf "%s" "${result}" | cut -d',' -f1)"
    details_list=($(printf "%s" "${result}" | cut -d',' -f6 | grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"))
    for x in ${!details_list[@]}
    do
        printf "%s" "$((x + 1)),$(inspect_ip_address "${details_list["${x}"]}" "${details_cidr}")\n" >> "./tmp-network-data"
    done

    printTable ","  "$(cat ./tmp-data)" && rm "./tmp-data"
    printf "\nSubnet Details:\n"
    printTable "," "$(cat ./tmp-network-data)" && rm "./tmp-network-data"
    if [[ "${inputted_sample_amount}" != "all" ]] &&
       [[ "${subnet_amount}" -ne 2 ]] &&
       [[ "${subnet_amount}" -gt "${inputted_sample_amount}" ]]
    then
        print_green "Add option -t=all to get all subnet details"
    fi
    exit 0
    ;;
3)
    [[ -z "${inputted_ip_address}" ]] && # Exit and print examples if variable is empty
    print_red "Mode usage example: subnet -m=3 -i=10.11.12.13" &&
    exit 1 ||
    if ! split_octet "${inputted_ip_address}" >/dev/null # Validate the variable
	then # Exit if it is not valid, else print the result
		exit 1
    else
        header="IP Address,Class,Type"
        result="$(ip_type "${inputted_ip_address}")"
        printf "%s\n" "${header}" "${result}" >> "./tmp-data"
        printTable ","  "$(cat ./tmp-data)" && rm "./tmp-data"
        exit 0
    fi
    ;;
4)
    [[ -z "${inputted_netmask}" && -z "${inputted_cidr}" ]] && # Exit and print examples if both variables are empty
    print_red "Mode usage example:" &&
    print_red "subnet -m=4 -n=255.255.0.0" &&
    print_red "subnet -m=4 -c=24" &&
    exit 1 ||
    [[ "${inputted_netmask}" ]] && # Proceed if netmask is provided
    if ! split_octet "${inputted_netmask}" >/dev/null # Validate the variable
    then # Exit if it is not valid, else print the result
        exit 1
    else
        header="Subnet Mask,CIDR Notation"
        result="$(netmask_to_cidr "${inputted_netmask}")"
        printf "%s\n" "${header}" "${inputted_netmask},${result}" >> "./tmp-data"
        printTable ","  "$(cat ./tmp-data)" && rm "./tmp-data"
        exit 0
    fi ||
    [[ "${inputted_cidr}" ]] && # Proceed if cidr is provided
    if  [[ ! "${inputted_cidr}" =~ ^-?[0-9]+$ ]] || # Check if it's not number
        [[ "${inputted_cidr}" -gt 32 ]] # Check if it's a number not greater than 32
    then # Exit if it is not valid, else print result
        print_red "Invalid input: ${inputted_cidr}"
        exit 1
    else
        header="CIDR Notation,Subnet Mask"
        result="$(cidr_to_netmask "${inputted_cidr}")"
        printf "%s\n" "${header}" "${inputted_cidr},${result}" >> "./tmp-data"
        printTable ","  "$(cat ./tmp-data)" && rm "./tmp-data"
        exit 0
    fi
    ;;
*)
    print_red "Unknown mode: '${mode}'"
    show_help
    exit 1
    ;;
esac