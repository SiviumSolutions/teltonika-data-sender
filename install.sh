#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ "$#" -ne 3 ]; then
    echo "Using $0 <http_host> <uuid> <token>"
    exit 1
fi

HTTP_HOST=$1
UUID=$2
TOKEN=$3


cat <<EOF > /etc/config/data_sender
config settings 'settings'
    option loglevel '1'

config collection '1'
    option sender_id '1'
    option format 'json'
    option output '2'
    list input '3'
    option name 'dataToNode'
    option retry '1'
    option retry_count '10'
    option enabled '1'
    option period '10'
    option retry_timeout '10'

config input '3'
    option format 'json'
    option plugin 'modbus'
    option modbus_filter 'all'
    option name 'data'
    option modbus_segments '5'

config output '2'
    option plugin 'http'
    option http_tls '0'
    option name 'dataToNode_output'
    option http_host '$HTTP_HOST'
    list http_header 'uuid: $UUID'
    list http_header 'token: $TOKEN'
EOF

cat <<EOF > /etc/config/modbus_client

config main 'main'
	option enabled '0'

config tcp_server '1'
	option server_id '1'
	option port '502'
	option name 'trb141'
	option delay '0'
	option frequency 'period'
	option dev_ipaddr '127.0.0.1'
	option reconnect '1'
	option timeout '10'
	option enabled '1'
	option period '10'

config request_1 '4'
	option name 'value'
	option enabled '1'
	option no_brackets '1'
	option function '3'
	option first_reg '1025'
	option data_type '32bit_float1234'
	option reg_count '2'

config request_1 '5'
	option name 'scale'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_float1234'
	option first_reg '1027'

config request_1 '6'
	option name 'pressure'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_float1234'
	option first_reg '1029'

config request_1 '7'
	option name 'pressure_formula_state'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_float1234'
	option first_reg '1031'

config request_1 '8'
	option name 'pressure_formula_coef'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_float1234'
	option first_reg '1033'
EOF

cat <<EOF > /etc/config/modbus_server
config modbus 'modbus'
	option timeout '0'
	option keepconn '0'
	option port '502'
	option md_data_type '0'
	option device_id '1'
	option regfilestart '1025'
	option clientregs '1'
	option regfilesize '10'
	option regfile '/storage/data/values.store'
	option enabled '1'
EOF

echo "The configuration was updated successfully."
echo "installing python..."

pokg update
opkg install python3-light

echo "Python installed"