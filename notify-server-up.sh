#!/bin/sh

# @author: David Colmenares
# @copyright: Copyright (C) 2023 David Colmenares
# @license: 4-Clause BSD

set -eu

encode_credentials() {
	echo "${CUSTOMER_ID}:${API_KEY}" | iconv -t utf-8 | base64 -w0 | sed s/K$/=/
}

main() {
	cd `dirname $0` # Go to the executable path to load the .env file

	curl -V > /dev/null 2>&1 || (echo "ERROR: curl must be installed" && exit 1)
	type base64 > /dev/null 2>&1 || (echo "ERROR: base64 must be in you PATH" && exit 1)
	type iconv > /dev/null 2>&1 || (echo "ERROR: iconv must be in your PATH" && exit 1)
	test ! -e $PWD/.env && echo "ERROR: you need to create a .env file" && exit 1

	. $PWD/.env # source file

	[ -z $URL ] && echo "ERROR: URL must be setted." && exit 1
	[ -z $API_KEY ] && echo "ERROR: API_KEY must be setted." && exit 1
	[ -z $CUSTOMER_ID ] && echo "ERROR: CUSTOMER_ID must be setted." && exit 1
	[ -z $PHONE_NUMBER ] && echo "ERROR: PHONE_NUMBER must be setted." && exit 1

	cd $OLDPWD # Go back to previous directory

	echo "Sending message..."

	until curl -s ${URL} > /dev/null 2>&1
	do
		sleep 5s
		echo 'Waiting for server to be online...'
	done

	curl --url ${URL} --silent \
		 --header "authorization: Basic `encode_credentials`" \
		 --header 'accept: application/json' \
		 --header 'content-type: application/x-www-form-urlencoded' \
		 --data is_primary=true \
		 --data message_type=ARN \
		 --data "phone_number=${PHONE_NUMBER}" \
		 --data-urlencode "message=$*"
}

main "$@"