# NOTIFY SERVER UP (SMS)

## BACKGROUND

In my country the electricity goes out a lot (by zones), which forces me to go to another neighborhood while I'm working.

The problem is that while I'm out of my house, I'm not sure when the electricity is back. So I decided to create this little script that will alert me when my raspberry is back online, then I can return home without worries.

## DESCRIPTION

The script uses a `.env` file that should contain the variables needed for the script to work properly. You should get the values from the account creation in [Telesign](https://portal.telesign.com/signup) and the registered phone number that you used.

## USAGE

After setting up the values in the `.env` you should add the following to your crontab:

`@reboot /path/to/your/script/notify-server-up.sh >> /var/log/notify-sms.log`

## NOTES

For some reason the `base64` string generated by  the `encode_credentials` function differs on the last character, in contrast of the one generated in https://developer.telesign.com/enterprise/reference/sendsms. That's why I had to add the `sed s/K$/=/` to the output, but in normal circunstances I guess it shouldn't be needed.