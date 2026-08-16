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
if gpasswd -d "$username" sudo; then
    echo "Removed '$username' from sudo group."
else
    echo "'$username' is not a member of the sudo group."
fi

# Add user to docker group
if usermod -aG docker "$username"; then
    echo "Added '$username' to docker group."
else
    echo "Failed to add '$username' to docker group."
    exit 1
fi

echo
echo "Current groups for '$username':"
id "$username"

echo
echo "Please ask the user to log out and log back in."
