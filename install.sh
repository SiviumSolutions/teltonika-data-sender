#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ "$#" -ne 3 ]; then
    echo "Using $0 <mqtt_host> <mqtt_port> <device_id> <user> <password>"
    exit 1
fi

MQTT_HOST=$1
PORT=$2
DEVICE_ID=$3
USER=$4
PASSWORD=$5


cat <<EOF > /etc/config/data_sender
config settings 'settings'
	option loglevel '1'

config collection '1'
	option sender_id '1'
	option format 'json'
	option output '2'
	option name 'dataToNode'
	option retry '1'
	option retry_count '10'
	option period '10'
	option retry_timeout '10'
	option enabled '1'
	list input '3'

config input '3'
	option plugin 'modbus'
	option modbus_filter 'all'
	option name 'data'
	option format 'custom'
	option format_str '{v:%data%,n:%name%}'
	option na_str 'null'
	option delimiter ','
	option modbus_segments '9'

config output '2'
	option name 'dataToNode_output'
	option mqtt_topic 'teltonika/$DEVICE_ID/data'
	option mqtt_tls '0'
	option mqtt_host '$MQTT_HOST'
	option mqtt_keepalive '60'
	option plugin 'mqtt'
	option mqtt_port '$PORT'
	option mqtt_qos '0'
	option mqtt_client_id ''
	option mqtt_use_credentials '1'
	option mqtt_username '$USER'
	option mqtt_password '$PASSWORD'
EOF

cat <<EOF > /etc/config/modbus_client
config main 'main'
	option enabled '1'

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

config request_1 '9'
	option name 'time'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_uint1234'
	option first_reg '365'

config request_1 '10'
	option name 'signal'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_int1234'
	option first_reg '4'

config request_1 '11'
	option name 'tr'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_uint1234'
	option first_reg '194'

config request_1 '12'
	option name 'tx'
	option enabled '1'
	option reg_count '2'
	option no_brackets '1'
	option function '3'
	option data_type '32bit_uint1234'
	option first_reg '196'

config tcp_server '14'
	option server_id '1'
	option port '502'
	option dev_ipaddr '127.0.0.1'
	option reconnect '1'
	option name 'trb141_alarms'
	option delay '0'
	option frequency 'period'
	option timeout '1'
	option period '1'
	option enabled '1'

config alarm_14 '15'
	option f_code '3'
	option data_type '32bit_float1234'
	option action '3'
	option host '$MQTT_HOST'
	option use_credentials '1'
	option username '$USER'
	option password '$PASSWORD'
	option tls_enabled '0'
	option topic 'teltonika/$DEVICE_ID/alarms'
	option keepalive '10'
	option client_id ''
	option enabled '1'
	option port '$PORT'
	option use_tls_root_ca '1'
	option qos '1'
	option register '1029'
	option condition '8'
	option redundancy_protection '0'
	option value '0'
	option actionfrequency '1'
	option json '{"name":"pressureAlarm", "time" : "%ut, "input": "%g1", "value": "%rv"}'
EOF

cat <<EOF > /etc/config/modbus_server
config modbus 'modbus'
	option port '502'
	option md_data_type '0'
	option device_id '1'
	option regfilestart '1025'
	option clientregs '1'
	option regfilesize '10'
	option regfile '/storage/data/values.store'
	option enabled '1'
	option keepconn '1'
	option timeout '5'
EOF

echo "The configuration was updated successfully."
echo "installing python..."

opkg update
opkg install python3-light

echo "DONE."

echo "Installing script..."
wget https://raw.githubusercontent.com/SiviumSolutions/teltonika-data-sender/main/main.py -O /storage/scripts/updatemodbus.py

chmod +x /storage/scripts/updatemodbus.py
echo "DONE."

echo "Setup autostart..."
if [ ! -f /etc/rc.local ]; then
    echo "#!/bin/sh -e" > /etc/rc.local
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local
fi

sed -i "/^exit 0/i python /storage/scripts/updatemodbus.py &" /etc/rc.local

echo "SUCCESS"


echo "Rebooting..."

reboot