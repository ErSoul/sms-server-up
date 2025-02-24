#!/data/data/com.termux/files/usr/bin/sh
#
## @author: David Colmenares
## @copyright: Copyright (C) 2023 David Colmenares
## @license: 4-Clause BSD

ERROR_STATE=false

log_error() {
	echo "`date '+%Y-%m-%d %H:%M:%S'` - $*" >&2
	ERROR_STATE=true
}

if type flock >/dev/null 2>&1
then
	exec 9>`dirname $0`/notif.lock
	flock -n 9 || log_error "ERROR: another instance of the script is running" 
else
	log_error "ERROR: command flock is not available."
fi

main() {
	cd `dirname $0` # Go to the executable path to load the state
	curl -V > /dev/null 2>&1 || log_error "ERROR: curl must be installed"
	jq -V > /dev/null 2>&1 || log_error "ERROR: jq must be installed"
	dpkg -s termux-api > /dev/null 2>&1 || log_error "ERROR: termux-api must be installed"

	while [ $# -gt 0 ]; do
		case $1 in
			-s)
				STATE_FILE=$2
				shift
				shift
				;;
			--ntfy-topic)
				NTFY_TOPIC=$2
				shift
				shift
				;;
			--ws-api-key)
				EVOLUTION_API_KEY=$2
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

	[ -f $PWD/.env ] && . $PWD/.env >/dev/null 2>&1

	[ -z $STATE_FILE ] && log_error "ERROR: STATE_FILE must be provided." 
	[ -z $NTFY_TOPIC ] && log_error "ERROR: NTFY_TOPIC must be provided."
	
	$ERROR_STATE && exit 1
	
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
		[ -n $NTFY_TOPIC ] && ntfy_notify -s "INFO: Power On" -t "info,power,zap" -m "You can arrive home safely"
		[ -n $EVOLUTION_API_KEY ] && ws_evolution_notify -m "¡Llegó la Luz!"
	elif [ $RESULT != "PLUGGED_AC" ] && [ $PREV_STATUS = "PLUGGED_AC" ]; then
		[ -n $NTFY_TOPIC ] && ntfy_notify -s "ALERT: Power Outage!" -p 'urgent' -t 'warning,power' -m "You're advised!"
		[ -n $EVOLUTION_API_KEY ] && ws_evolution_notify -m "Se fué la Luz. :-("
	fi
}

ntfy_notify() {
	while getopts s:p:t:m: OPT # s - SUBJECT or TITLE ## p - PRIORITY (default, urgent) ## t - TAGS (comma separated) ## m - MESSAGE content
	do
		case $OPT in
		s) TITLE="$OPTARG";;
		p) PRIORITY="$OPTARG";;
		t) TAGS="$OPTARG";;
		m) MESSAGE="$OPTARG";;
		?) echo "ERROR: input error." && return 1
		esac
	done
	
	until curl -s \
		-H "Title: ${TITLE}" \
		-H "Priority: ${PRIORITY:-default}" \
		-H "Tags: ${TAGS}" \
		-d "${MESSAGE}" \
		https://ntfy.sh/$NTFY_TOPIC 2>&1 > /dev/null
	do
		log_error "ERROR: waiting for connection for https://ntfy.sh"
		sleep 5
	done
}

ws_evolution_notify() {
	while getopts d:s:p:t:m: OPT # s - Instance ## a - ApiKey ## m - MESSAGE content
	do
		case $OPT in
		a) EVOLUTION_API_KEY="$OPTARG";;
		d) EVOLUTION_API_FQDN="$OPTARG";;
		s) EVOLUTION_API_INSTANCE="$OPTARG";;
		t) WS_PHONES="$OPTARG";;
		m) MESSAGE="$OPTARG";;
		?) echo "ERROR: input error." && return 1
		esac
	done
	
	local IFS=", \n"
	
	for PHONE in $WS_PHONES
	do
			until curl -s \
				-H "Content-Type: application/json" \
				-H "apikey: ${EVOLUTION_API_KEY}" \
				-d "{\"number\": \"${PHONE}\", \"text\": \"${MESSAGE}\"}" \
				"https://$EVOLUTION_API_FQDN/message/sendText/$EVOLUTION_API_INSTANCE" 2>&1 > /dev/null
			do
				log_error "ERROR: waiting for connection for https://$EVOLUTION_API_FQDN"
				sleep 5
			done
	done
}

help_usage() {
	printf "usage: `basename $0` [-s FILE]\n\n"
	cat << EOF
Notify when server is on ac power or on battery.

Options:

-h --help --usage		Show this help message.
-s FILE 			File to read previous state
--ntfy-topic NTFY_TOPIC		Set topic from https://ntfy.sh
--ws-api-key API_KEY		Set topic from https://doc.evolution-api.com/v2/en/env#authentication
EOF
exit 0
}

main $@
