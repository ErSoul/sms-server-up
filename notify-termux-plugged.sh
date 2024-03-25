#!/data/data/com.termux/files/usr/bin/sh
#
## @author: David Colmenares
## @copyright: Copyright (C) 2023 David Colmenares
## @license: 4-Clause BSD

log_error() {
	echo "`date '+%Y-%m-%d %H:%M:%S'` - $*" >&2
	return 1
}

exec 9>`dirname $0`/notif.lock
flock -n 9 || log_error "ERROR: another instance of the script is running" 

help_usage() {
	echo -e "usage: `basename $0` [-s FILE]\n"
	cat << EOF
Notify when server is on ac power or on battery.

Options:

-h --help --usage	Show this help message.
-s FILE File to read previous state
EOF
exit 0
}

main() {
	cd `dirname $0` # Go to the executable path to load the state
	curl -V > /dev/null 2>&1 || (log_error "ERROR: curl must be installed" >&2)
	jq -V > /dev/null 2>&1 || (log_error "ERROR: jq must be installed" >&2)
	dpkg -s termux-api > /dev/null 2>&1 || (log_error "ERROR: termux-api must be installed" >&2)

	while [ $# -gt 0 ]; do
		case $1 in
			-s)
				STATE_FILE=$2
				shift
				shift
				;;
			-h|--help|--usage)
				help_usage
				;;
			-*|--*)
				log_error "Invalid option $1"
				;;
			*)
				shift
				;;
		esac
	done

	[ -f $PWD/.env ] && . $PWD/.env 2>&1 >/dev/null

	[ -z $STATE_FILE ] && log_error "ERROR: STATE_FILE must be provided." 
	[ -z $NTFY_TOPIC ] && log_error "ERROR: NTFY_TOPIC must be provided."
	
	if [ -e $STATE_FILE ]; then
		PREV_STATUS=`cat $STATE_FILE`
	else
		echo "UNPLUGGED" > $STATE_FILE
		PREV_STATUS="UNPLUGGED"
	fi
	
	RESULT=`termux-battery-status | jq -r .plugged`
	echo $RESULT > $STATE_FILE
	
	if [ $RESULT = "PLUGGED_AC" ] && [ $PREV_STATUS != "PLUGGED_AC" ]
	then
		until curl -s \
			-H "Title: INFO: Power On" \
			-H "Priority: default" \
			-H "Tags: info,power,zap" \
			-d "You can arrive home safely" \
			ntfy.sh/$NTFY_TOPIC 2>&1 > /dev/null
		do
			log_error "ERROR: waiting for connection" 
			sleep 5
		done
	elif [ $RESULT != "PLUGGED_AC" ] && [ $PREV_STATUS = "PLUGGED_AC" ]; then
		until curl -s \
			-H "Title: ALERT: Power Outage!" \
			-H "Priority: urgent" \
			-H "Tags: warning,power" \
			-d "You're advised!" \
			ntfy.sh/$NTFY_TOPIC 2>&1 > /dev/null
		do
			log_error "ERROR: waiting for connection"
			sleep 5
		done
	fi
}

main $@
