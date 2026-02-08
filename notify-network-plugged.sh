#!/data/data/com.termux/files/usr/bin/sh
#
## @author: David Colmenares
## @copyright: Copyright (C) 2023 David Colmenares
## @license: 4-Clause BSD

help_usage() {
	echo -e "usage: `basename $0` [-f FILE] <TARGET>\n"
	cat << EOF
Notify if server is powered on or off.

Argument:
 TARGET Hostname or IP Address

Options:

-h --help --usage	Show this help message.
-t FILE File to read previous state
EOF
exit 0
}

main() {
	cd `dirname $0` # Go to the executable path to load the state
	
	curl -V > /dev/null 2>&1 || (echo "ERROR: curl must be installed" >&2 && exit 1)

	# Windows ping returns exit status of 1
	if [ "$OS" != "Windows_NT" ]; then
		ping -V > /dev/null 2>&1 || (echo "ERROR: ping must be installed" >&2 && exit 1)
	fi

	while [ $# -gt 0 ]; do
		case $1 in
			-h|-H|--help|--usage)
				help_usage
				;;
			-f|-F)
				STATE_FILE=$2
				shift
				shift
				;;
			-t|-T)
				TOPIC=$2
				shift
				shift
				;;
			-*|--*)
				echo "Invalid option $1" >&2
				exit 1
				;;
			*)
				TARGET=$1
				shift
				;;
		esac
	done

	[ -z $STATE_FILE ] && echo "ERROR: FILE must be provided." >&2 && exit 1
	[ -z $TOPIC ] && echo "ERROR: TOPIC must be provided. (ntfy topic)" >&2 && exit 1
	[ -z $TARGET ] && echo "ERROR: TARGET must be setted." >&2 && exit 1
	
	OK=0
	FAULT=1
	
	if [ -e $STATE_FILE ]; then
		PREV_STATUS=`cat $STATE_FILE`
	else
		echo $FAULT > $STATE_FILE
		PREV_STATUS=$FAULT
	fi
	
	ping -c5 $TARGET >/dev/null 2>&1 
	RESULT=$? 
	echo $RESULT > $STATE_FILE
	
	if [ $RESULT -eq $OK ] && [ $PREV_STATUS -ne $OK ]
	then
		until curl -s \
			-H "Title: INFO: Power On" \
			-H "Priority: default" \
			-H "Tags: info,power" \
			-d "You can arrive safely to home" \
			ntfy.sh/$TOPIC 2>&1 > /dev/null
		do
			echo "ERROR: waiting for connection" >&2
		done
	elif [ $RESULT -ne $OK ] && [ $PREV_STATUS -eq $OK ]; then
		until curl -s \
			-H "Title: ALERT: Power Outage!" \
			-H "Priority: urgent" \
			-H "Tags: warning,power" \
			-d "You're advised!" \
			ntfy.sh/$TOPIC 2>&1 > /dev/null
		do
			echo "ERROR: waiting for connection" >&2
		done
	fi
}

main $@
