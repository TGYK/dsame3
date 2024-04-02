#!/bin/bash

#Author: Justin Tongay <TGYK>
#Description:
#   This simple script is designed to be called by dsame
#   on a SAME match in order to forward the message through
#   Pushover while avoiding duplicate message spam and
#   logging all events to a file in an archival manner.
#
#Example usage: 
#   python ./dsame.py --source ./scripts/demod.sh --call ./scripts/alarm.sh --command "{MESSAGE}" "{event} until {end}"
#
#	*Note: "demod.sh" is a script that will capture and/or 
#	demodulate a raw alert into text on stdout to be used by dsame.
#	A typical source script on linux with an RTL-SDR would involve
#   rtl_fm piped into multimon-ng as its contents:
#   	rtl_fm -f FREQ -s 22050 -g GAIN -p PPM -M fm - | multimon-ng -t raw -a EAS -

LOCKFILE=lock
WAITFORLOCK=true
WAITTIME=1
MESSAGE=$1
TITLE=$2
LOGFILE=events.txt
APP_TOKEN="<YOUR-TOKEN-HERE>"
USER_TOKEN="<YOUR-TOKEN-HERE>"

#Check usage
if [ $# -eq 0 ]; then
	echo "Usage: ./alarm.sh <message> [title]"
	exit
fi

#Check/wait for lock
if [ $WAITFORLOCK == "true" ]; then
	while [ $WAITFORLOCK == "true" ]; do
		if { set -C; 2>/dev/null >$LOCKFILE; }; then
			trap "rm -f $LOCKFILE" EXIT
			WAITFORLOCK=false
		else
			echo "Lock file exists… Waiting $WAITTIME seconds and trying again."
			sleep $WAITTIME
		fi
	done
fi

#Check for duplicate messages
LASTMSG=$(tail -n 1 "$LOGFILE")
if [ "$LASTMSG" == "$MESSAGE" ]; then
	echo "Duplicate alert, exiting!"
	exit
fi

#If no title supplied.. Make one
if [ $# -lt 2 ]; then
	TITLE="`whoami`@${HOSTNAME}"
fi

#If logfile exists and is larger than 1MB, remove it
if [ -e $LOGFILE ]; then
	if [[ $(find $LOGFILE -type f -size +1024000c 2>/dev/null) ]]; then
		rm $LOGFILE
	fi
fi

#Log the current date to the logfile
echo "#### $(date +"%A %B %d, %Y %l:%M %p")" >> $LOGFILE

#Log the message to the logfile
echo $MESSAGE >> $LOGFILE

#Send message via pushover
wget -4 https://api.pushover.net/1/messages.json --post-data="token=$APP_TOKEN&user=$USER_TOKEN&message=$MESSAGE&title=$TITLE&priority=1" -qO- > /dev/null 2>&1 &
