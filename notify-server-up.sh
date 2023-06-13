#!/bin/sh

# @author: David Colmenares
# @copyright: Copyright (C) 2023 David Colmenares
# @license: 4-Clause BSD

set -e

help_usage() {
	echo -e "usage: `basename $0` [--twilio|--telesign] <message>\n"
	cat << EOF
Notify server has started.

Argument:
 message		Message to be sent.

Options:

 -h --help --usage	Show this help message.
 --email		Send email notification.
 --twilio		Use the Twilio service API.
 --telesign		Use the Telesign service API.
EOF
	exit 0
}

telesign_encode_credentials() {
	echo "${CUSTOMER_ID}:${API_KEY}" | iconv -t utf-8 | base64 -w0 | sed s/K$/=/
}

main() {
	cd `dirname $0` # Go to the executable path to load the .env file

	curl -V > /dev/null 2>&1 || (echo "ERROR: curl must be installed" >&2 && exit 1)
	type base64 > /dev/null 2>&1 || (echo "ERROR: base64 must be in you PATH" >&2 && exit 1)
	type iconv > /dev/null 2>&1 || (echo "ERROR: iconv must be in your PATH" >&2 && exit 1)
	test ! -e $PWD/.env && echo "ERROR: you need to create a .env file" >&2 && exit 1
	
	ARGS="$*"
	EMAIL=false
	
	while [ $# -gt 0 ]; do
		case $1 in
			--telesign)
				SERVICE="telesign"
				shift
				;;
			--twilio)
				SERVICE="twilio"
				shift
				;;
			--email)
				EMAIL=true
				shift
				;;
			-h|--help|--usage)
				help_usage
				;;
			-*|--*)
				echo "Invalid option $1"
				exit 1
				;;
			*)
				POS_ARGS="$POS_ARGS $1" # Will be added to msg body
				shift
				;;
		esac
	done
	
	# Two substring present in string. src: https://unix.stackexchange.com/a/55391/236112
	echo $ARGS | awk 'err=0; /--twilio/ && /--telesign/ && err=1; {exit err}' > /dev/null 2>&1 || (echo "error: must specify twilio or telesign." >&2 && exit 1)
	echo $ARGS | grep -i -e "--telesign" -e "--twilio" > /dev/null 2>&1 || (echo "error: must specify twilio or telesign." >&2 && exit 1)
  if $EMAIL; then
  	type sendemail > /dev/null 2>&1 || (echo "ERROR: sendemail must be installed. (https://github.com/mogaal/sendemail)" >&2 && exit 1)
  fi
	
	set -- $POS_ARGS

	. $PWD/.env # source file

	[ -z $URL ] && echo "ERROR: URL must be setted." >&2 && exit 1
	[ -z $API_KEY ] && echo "ERROR: API_KEY must be setted." >&2 && exit 1
	[ -z $CUSTOMER_ID ] && echo "ERROR: CUSTOMER_ID must be setted." >&2 && exit 1
	[ -z $PHONE_TARGET ] && echo "ERROR: PHONE_TARGET must be setted." >&2 && exit 1
	[ -z $SERVICE ] || [ $SERVICE = 'twilio' ] && [ -z $PHONE_SRC ] && echo "ERROR: PHONE_SRC must be setted." >&2 && exit 1
	
	if $EMAIL; then
		[ -z $SMTP_HOST ] && echo "ERROR: SMTP_HOST must be setted." >&2 && exit 1
		[ -z $SMTP_PORT ] && echo "ERROR: SMTP_PORT must be setted." >&2 && exit 1
		[ -z $FROM_ADDRESS ] && echo "ERROR: FROM_ADDRESS must be setted." >&2 && exit 1
		[ -z $FROM_PASSWORD ] && echo "ERROR: FROM_PASSWORD must be setted." >&2 && exit 1
		[ -z $TO_ADDRESS ] && echo "ERROR: TO_ADDRESS must be setted." >&2 && exit 1
	fi

	cd $OLDPWD # Go back to previous directory

	echo "Sending message..."

	until curl -s ${URL} > /dev/null 2>&1
	do
		sleep 5s
		echo 'Waiting for server to be online...'
	done
	
	$EMAIL && sendemail -f $FROM_ADDRESS -t $TO_ADDRESS -u "Server powered on." -m "$*" -s $SMTP_HOST:$SMTP_PORT -xu $FROM_ADDRESS -xp $FROM_PASSWORD -o tls=yes

	case $SERVICE in
		telesign)
			curl --url ${URL} --silent \
				 --header "authorization: Basic `telesign_encode_credentials`" \
				 --header 'accept: application/json' \
				 --header 'content-type: application/x-www-form-urlencoded' \
				 --data is_primary=true \
				 --data message_type=ARN \
				 --data "phone_number=${PHONE_TARGET}" \
				 --data-urlencode "message=$*"
			;;
		twilio)
			curl --url ${URL} --silent \
				 --data-urlencode "message=$*" \
				 --data-urlencode "Body=$*" \
				 --data-urlencode "From=${PHONE_SRC}" \
				 --data-urlencode "To=${PHONE_TARGET}" \
				 -u "${CUSTOMER_ID}:${API_KEY}"
			;;
		*)
			echo "Invalid option: $SERVICE" >&2
		;;
	esac
}

main "$@"
