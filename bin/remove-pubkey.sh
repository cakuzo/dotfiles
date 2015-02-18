#!/bin/bash
#
# this works only in internal networks with rootlogin enabled for ssh
#

#function for sending output to stderr
echoerr() { echo "$@" 1>&2; }
# check if script is executed as root, otherwise it would not be possible to read pubkey files from other home directories
if [ $(id -u) -ne 0 ]; then
	echoerr "Error: Only root dude, only root!"
	exit 1
fi

# loop for reading Username, if you put in a wrong username you have the choice to try another username
while true; do 
	read -ep "Username: " username
	pubkey="/home/$username/.ssh/id_rsa.pub"
	
	if [ -r $pubkey ]; then
		echo -e "Public Key: $(cat $pubkey)"
		break;
	else
		echoerr "Error reading file: $pubkey"
		read -n1 -ep "Try again? [y|n]: " answer
		if [ $answer != "y" ]; then
			echo "Bye bye!"
			exit 1
		fi
	fi
done

# list of servers
source serverlist
# overriding serverlist

echo "Serverlist: $servers"
read -n1 -ep "Would you like to proceed? [y|n]: " answer

if [ $answer != "y" ]; then
	echoerr "NoooooooooooooOOOoooOO...."
	exit 1
fi

# Here starts the real action... uncomment below line if you are debugging stuff
#exit 0

for server in $servers; do
#  echo -n "$server: " && ~/bin/ssh-copy-id -i $pubkey $server
  echo -n "$server: " && ssh $server "sed -i '/$username@hopserver/d' ~/.ssh/authorized_keys" && echo $username REMOVED
done
