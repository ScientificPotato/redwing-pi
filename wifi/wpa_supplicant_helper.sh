#!/bin/bash
# Run this script with bash shell
# wpa_supplicant helper script

clear

# Root check (Insert at beginning)
if [ `id -u` -ne 0 ]; then
	echo "Error: This script has to be run by root."
	exit 2
fi

# Generic error flag
ERROR=0

TITLE="Wireless Connection Helper\n==========================\n"

printf "$TITLE"
echo ""
echo "Enter the full path for the configuration file we are generating or using..."
printf "> "
read CONFIG_PATH

if [ "$CONFIG_PATH" = "" ]; then
	echo "Path must be specified. Exiting..."
	exit 2
fi

printf "Need to change script to see if file exists. If it does, skip the next parts until XXXXHEREXXXX"

exit 0

clear
printf "Wireless device list\n"
LIST=`ifconfig | grep Link`
DEVICES=""
for LINE in `echo $LIST | grep -o -e "[^.]*"`;do
	if [[ "$LINE" == "w"* ]];then
		DEVICES=$DEVICES" $LINE"
	fi
done


if [ "$DEVICES" != "" ];then
	for DEVICE in `echo $DEVICES`;do
		echo ">> $DEVICE"
	done
	echo ""

	while [ "$IFACE" = "" ];do
		IFACE=""

		echo "Please type the (case-sensitive) name of the wifi device to use"
		printf "> "
		read INP_IFACE

		for DEVICE in `echo $DEVICES`;do
			if [ "$DEVICE" = "$INP_IFACE" ];then
				IFACE=$INP_IFACE
			fi
		done
	done
else
	echo "No devices found. Exiting..."
	exit 0
fi

echo ""
echo "Processing..."

echo "Bringing up $IFACE and killing dhcpcd"
ifconfig $IFACE up
pkill dhcpcd
sleep 2

# PAGE 2
clear

printf "$TITLE-> Getting list of local wireless networks\n"

############################
# Get list of ESSIDs
count=$(iwlist scan 2>/dev/null | grep Cell | wc -l)
iwlist scan 2>/dev/null | grep ESSID > /tmp/buffer.cr
(( count++ ))

flag=1
CONFIRM=0
while [ $CONFIRM -eq 0 ];do
	while [ $flag -lt $count ]; do
		cell=$(iwlist scan 2>/dev/null | grep "Cell 0$flag")
		essid=$(sed -n -e "${flag}p" /tmp/buffer.cr)

		echo -n "$cell"
		echo "$essid"

		(( flag++ ))
	done
	
	echo ""
	printf "Enter ESSID for the connection you want to use\n> "; read ESSID;
	printf "Enter password for this connection\n> "; read PASS;
	printf "\n\n\n"

	printf "Please confirm the connection information\n"
	printf "ESSID: $ESSID\nPassword: $PASS\n"

	printf "Is this correct? (y¦n):"; read -n 1 CONFIRM

	if [ "$CONFIRM" = "y" ]; then
		echo "Generating WPA passphrase"
		wpa_passphrase $ESSID "$PASS" > $CONFIG_PATH
		CONFIRM=1
	else
		CONFIRM=0
		printf "\n----------------------------------------------\n"
	fi
	rm /tmp/buffer.cr > /dev/null 2>&1
done




####################
clear
printf "$TITLE"
echo "Attempting to bring the wifi connection up with the details provided"
sleep 2

wpa_supplicant -B -Dwext -i $IFACE -c $CONFIG_PATH >/dev/null 2>&1

CONFIRM=0

while [ $CONFIRM -eq 0 ]; do
	echo "Will you connect to this network and get an IP address from the router via DHCP or do you want to set a static address?"
	echo "1. DHCP"
	echo "2. Static"
	printf "\n> "
	read NET_TYPE

	case $NET_TYPE in
		1)
			echo "Configuring dhcpcd"
			dhcpcd $IFACE >/dev/null >/dev/null 2>&1
			CONFIRM=1
		;;
		2)
			echo "Enter details of your static connection"
			echo -n "IP Adress: "; read IP
			echo -n "Gateway: "; read GW
			echo -n "Primary DNS: "; read DNS

			echo "Setting IP address and adding gateway route"
			ifconfig $IFACE $IP
			route add default gw $GW

			echo "Generating resolv.conf"
			echo "# Generated by wpa_supplicant helper script" > /etc/resolv.conf
			echo "# /etc/resolv.conf.head can replace this line" >> /etc/resolv.conf
			echo "nameserver $DNS" >> /etc/resolv.conf
			echo "# /etc/resolv.conf.tail can replace this line" >> /etc/resolv.conf
			CONFIRM=1
		;;
		*)
			echo "Please press 1 or 2"
		;;
	esac

	if [ $CONFIRM -eq 1 ];then
		printf "\n\nProcess complete. Configuration file written to $CONFIG_PATH\n\n"
	else
		printf "\n\nPlease try again...\n\n"
	fi
done

XXXXHEREXXXX



# Determine whether the lines are already written to interfaces
clear
printf "$TITLE"
echo "Do you want to automatically start this connection on boot-up? y/n"
read -n 1 -s BOOT_CHOICE

MANUAL=0
if [ "$BOOT_CHOICE" = "y" ];then
	CHECK=`cat /etc/network/interfaces | grep $IFACE`
	if [ "$CHECK" = "" ];then
		echo "" >> /etc/network/interfaces
		echo "auto $IFACE" >> /etc/network/interfaces
		echo "iface $IFACE inet dhcp" >> /etc/network/interfaces
		echo "wpa-conf $CONFIG_PATH" >> /etc/network/interfaces
	else
		echo "A connection to $IFACE is already in /etc/network/interfaces. Please ensure that the following lines are there for $IFACE"
		echo "auto $IFACE"
		echo "iface $IFACE inet dhcp"
		echo "wpa-conf $CONFIG_PATH"
		echo ""
	fi
fi
exit 0
if [ $MANUAL -eq 1 ];then
	echo "Your connection can only be started manually by using the following command:"
	echo "wpa_supplicant -B -Dwext -i $IFACE -c $CONFIG_PATH"
	printf "\n\n"
fi
