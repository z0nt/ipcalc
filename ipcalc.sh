#!/bin/sh
#
# Copyright (c) 2010 Andrey Zonov <andrey@zonov.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# is_number number
#	Function returns 0 if $1 is number, otherwise returns 1.
#

is_number()
{
	if [ $# -ne 1 -o -z "$1" ]; then
		return 1
	fi

	if [ "$1" -eq "$1" ] 2> /dev/null; then
		return 0
	fi

	return 1
}

#
# ipv4_to_ip10 ipv4 ip10
#	Function converts IPv4 address to decimal address. $1 must be IPv4
#	address. $2 must be name of variable to save decimal address.
#

ipv4_to_ip10()
{
	local __ipv4 __ip10
	local _ip1 _ip2 _ip3 _ip4 _oct

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	__ipv4="$1"
	__ip10="$2"

	_ip1=${__ipv4%.*.*.*}
	_ip2=${__ipv4%.*.*}; _ip2=${_ip2#*.}
	_ip3=${__ipv4#*.*.}; _ip3=${_ip3%.*}
	_ip4=${__ipv4#*.*.*.}

	for _oct in "${_ip1}" "${_ip2}" "${_ip3}" "${_ip4}"; do
		if [ -z "${_oct}" -o "${_oct}" = "${__ipv4}" ]; then
			return 1
		fi

		if ! is_number "${_oct}"; then
			return 1
		fi

		if [ "${_oct}" -lt 0 -o "${_oct}" -gt "$(($pow8 - 1))" ]; then
			return 1
		fi
	done

	eval eval \${__ip10}=$((${_ip1} << 24 | ${_ip2} << 16 | ${_ip3} << 8 | ${_ip4}))

	return 0
}

#
# ip10_to_ipv4 ip10 ipv4
#	Function converts decimal address to IPv4 address. $1 must be decimal
#	address. $2 must be name of variable to save IPv4 address.
#

ip10_to_ipv4()
{
	local __ip10 __ipv4
	local _ip1 _ip2 _ip3 _ip4

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	__ip10="$1"
	__ipv4="$2"

	if ! is_number "${__ip10}"; then
		return 1
	fi

	if [ "${__ip10}" -lt 0 -o "${__ip10}" -gt "$(($pow32 - 1))" ]; then
		return 1
	fi

	_ip1=$((((${__ip10} >> 24)) & 0xFF))
	_ip2=$((((${__ip10} >> 16)) & 0xFF))
	_ip3=$((((${__ip10} >> 8)) & 0xFF))
	_ip4=$((${__ip10} & 0xFF))

	eval eval \${__ipv4}="${_ip1}.${_ip2}.${_ip3}.${_ip4}"

	return 0
}

#
# is_ipv4_belong_net ipv4 network/mask
#	Function returns 0 if $1 address belongs $2 network, otherwise return 1.
#	$1 must be IPv4 address. $2 must be IPv4 network in CIDR notation.
#

is_ipv4_belong_net()
{
	local _ipv4 _network _mask _ip_net
	local _ip10 _mask10 _ip_net10

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	_ipv4="$1"
	_net="$2"

	_network="${_net%/*}"
	_mask="${_net#*/}"

	if ! is_number "${_mask}"; then
		return 1
	fi

	if [ "${_mask}" -lt 0 -o "${_mask}" -gt 32 ]; then
		return 1
	fi

	if ! ipv4_to_ip10 "${_ipv4}" "_ip10"; then
		return 1
	fi

	_hosts=$((1 << $((32 - ${_mask}))))
	_mask10=$(($pow32 - ${_hosts}))
	_ip_net10=$((${_ip10} & ${_mask10}))
	if ! ip10_to_ipv4 "${_ip_net10}" "_ip_net"; then
		return 1
	fi

	if [ "${_ip_net}" != "${_network}" ]; then
		return 1
	fi

	return 0
}

#
# get_netmask network/mask netmask
#	Function generates IPv4 netmask from IPv4 network in CIDR notation.
#	$1 must be IPv4 network in CIDR notation. $2 must be name of variable
#	to save netmask.
#

get_netmask()
{
	local _net _netmask _network _mask _hosts _mask_tmp
	local _mask10

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	_net="$1"
	_netmask="$2"

	_network="${_net%/*}"
	_mask="${_net#*/}"

	if ! is_number "${_mask}"; then
		return 1
	fi

	if [ "${_mask}" -lt 0 -o "${_mask}" -gt 32 ]; then
		return 1
	fi

	_hosts=$((1 << $((32 - ${_mask}))))
	_mask10=$(($pow32 - ${_hosts}))
	if ! ip10_to_ipv4 "${_mask10}" "_mask_tmp"; then
		return 1
	fi

	eval eval \${_netmask}="${_mask_tmp}"

	return 0
}

#
# get_network ipv4/mask network/mask
#	Function generates IPv4 network in CIDR notation from IPv4 address
#	with mask in CIDR notation. $1 must be IPv4 address with mask in CIDR
#	notation. $2 must be name of variable to save network.
#

get_network()
{
	local _ipv4mask _network _ipv4 _mask _hosts _network_tmp
	local _ip10 _mask10 _network10

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	_ipv4mask="$1"
	_network="$2"

	_ipv4="${_ipv4mask%/*}"
	_mask="${_ipv4mask#*/}"

	if ! is_number "${_mask}"; then
		return 1
	fi

	if [ "${_mask}" -lt 0 -o "${_mask}" -gt 32 ]; then
		return 1
	fi

	if ! ipv4_to_ip10 "${_ipv4}" "_ip10"; then
		return 1
	fi
	_hosts=$((1 << $((32 - ${_mask}))))
	_mask10=$(($pow32 - ${_hosts}))
	_network10=$((${_ip10} & ${_mask10}))
	if ! ip10_to_ipv4 "${_network10}" "_network_tmp"; then
		return 1
	fi

	eval eval \${_network}="${_network_tmp}/${_mask}"

	return 0
}

#
# get_minhost network/mask minhost
#	Function generates minimum host for network. $1 must be IPv4 network
#	in CIDR notation. $2 must be name of variable to save minimum host.
#

get_minhost()
{
	local _net _minhost _network _mask _hosts _minhost_tmp
	local _network10 _mask10 _minhost10

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	_net="$1"
	_minhost="$2"

	_network="${_net%/*}"
	_mask="${_net#*/}"

	if ! is_number "${_mask}"; then
		return 1
	fi

	if [ "${_mask}" -lt 0 -o "${_mask}" -gt 32 ]; then
		return 1
	fi

	# Network with /31 mask has minimum host equal to network
	if [ "${_mask}" -eq 31 ]; then
		eval eval \${_minhost}="${_network}"
		return 0
	fi

	# Network with /32 mask has no minimum host
	if [ "${_mask}" -eq 32 ]; then
		return 0
	fi

	if ! ipv4_to_ip10 "${_network}" "_network10"; then
		return 1
	fi
	_hosts=$((1 << $((32 - ${_mask}))))
	_mask10=$(($pow32 - ${_hosts}))
	_minhost10=$((${_network10} + 1))

	if ! ip10_to_ipv4 "${_minhost10}" "_minhost_tmp"; then
		return 1
	fi

	eval eval \${_minhost}="${_minhost_tmp}"

	return 0
}

#
# get_maxhost network/mask maxhost
#	Function generates maximum host for network. $1 must be IPv4 network
#	in CIDR notation. $2 must be name of variable to save maximum host.
#

get_maxhost()
{
	local _reserve _net _maxhost _network _mask _hosts _maxhost_tmp
	local _network10 _mask10 _maxhost10

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	_reserve=2

	_net="$1"
	_maxhost="$2"

	_network="${_net%/*}"
	_mask="${_net#*/}"

	if ! is_number "${_mask}"; then
		return 1
	fi

	if [ "${_mask}" -lt 0 -o "${_mask}" -gt 32 ]; then
		return 1
	fi

	if [ "${_mask}" -ge 31 ]; then
		_reserve=1
	fi

	if ! ipv4_to_ip10 "${_network}" "_network10"; then
		return 1
	fi
	_hosts=$((1 << $((32 - ${_mask}))))
	_mask10=$(($pow32 - ${_hosts}))
	_maxhost10=$((${_network10} + ${_hosts} - ${_reserve}))

	if ! ip10_to_ipv4 "${_maxhost10}" "_maxhost_tmp"; then
		return 1
	fi

	eval eval \${_maxhost}="${_maxhost_tmp}"

	return 0
}

#
# get_broadcast network/mask broadcast
#	Function generates broadcast address for network. $1 must be IPv4
#	network in CIDR notation. $2 must be name of variable to save
#	broadcast address.
#

get_broadcast()
{
	local _net _broadcast _network _mask _hosts _broadcast_tmp
	local _network10 _mask10 _broadcast10

	if [ $# -ne 2 -o -z "$1" -o -z "$2" ]; then
		return 1
	fi

	_net="$1"
	_broadcast="$2"

	_network="${_net%/*}"
	_mask="${_net#*/}"

	if ! is_number "${_mask}"; then
		return 1
	fi

	if [ "${_mask}" -lt 0 -o "${_mask}" -gt 32 ]; then
		return 1
	fi

	# Network with /31 or /32 mask has no broadcast address
	if [ "${_mask}" -ge 31 ]; then
		return 0
	fi

	if ! ipv4_to_ip10 "${_network}" "_network10"; then
		return 1
	fi
	_hosts=$((1 << $((32 - ${_mask}))))
	_mask10=$(($pow32 - ${_hosts}))
	_broadcast10=$((${_network10} + ${_hosts} - 1))

	if ! ip10_to_ipv4 "${_broadcast10}" "_broadcast_tmp"; then
		return 1
	fi

	eval eval \${_broadcast}="${_broadcast_tmp}"

	return 0
}

main()
{
	local ip cidr_mask netmask network minhost maxhost broadcast hosts reserve

	if [ $# -ne 1 ]; then
		echo "usage: $0 ip.ip.ip.ip/mask"
		exit 1
	fi

	ip=${1%/*}
	cidr_mask=${1#*/}

	if [ "$ip" = "$1" -o "$cidr_mask" = "$1" ]; then
		echo "usage: $0 ip.ip.ip.ip/mask"
		exit 1
	fi

	if ! get_netmask "$ip/$cidr_mask" "netmask"; then
		echo "Bad netmask"
		exit 1
	fi
	if ! get_network "$ip/$cidr_mask" "network"; then
		echo "Bad IP"
		exit 1
	fi
	get_minhost "$network" "minhost"
	get_maxhost "$network" "maxhost"
	get_broadcast "$network" "broadcast"
	hosts=$((1 << $((32 - $cidr_mask))))
	reserve=2
	if [ "$cidr_mask" -ge 31 ]; then
		reserve=0
	fi

	# print result
	echo "address:   $ip"
	echo "mask:      $netmask = $cidr_mask"
	echo "subnet:    $network"
	echo "min host:  $minhost"
	echo "max host:  $maxhost"
	echo "broadcast: $broadcast"
	echo "hosts:     $(($hosts-$reserve))"
}

pow32=$((1 << 32))
pow24=$((1 << 24))
pow16=$((1 << 16))
pow8=$((1 << 8))

if [ $# -ge 1 ]; then
	main "$@"
fi
