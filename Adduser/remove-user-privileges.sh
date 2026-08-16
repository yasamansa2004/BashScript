#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Only root may modify user privileges."
    exit 1
fi

read -rp "Enter username: " username

if ! id "$username" &>/dev/null; then
    echo "User '$username' does not exist."
    exit 1
fi

# Remove user from sudo group
if id -nG "$username" | grep -qw sudo; then
    gpasswd -d "$username" sudo
    echo "Removed '$username' from sudo group."
else
    echo "'$username' is not a member of the sudo group."
fi

# Remove user from docker group
if id -nG "$username" | grep -qw docker; then
    gpasswd -d "$username" docker
    echo "Removed '$username' from docker group."
else
    echo "'$username' is not a member of the docker group."
fi

echo
echo "Current groups for '$username':"
id "$username"

echo
echo "Please ask the user to log out and log back in."
