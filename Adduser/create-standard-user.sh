#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Only root may create users."
    exit 1
fi

read -rp "Enter username: " username

if id "$username" &>/dev/null; then
    echo "User '$username' already exists."
    exit 1
fi

# Create user
if adduser "$username"; then
    echo
    echo "User '$username' created successfully."
else
    echo "Failed to create user."
    exit 1
fi

echo
echo "Current groups for '$username':"
id "$username"

echo
echo "User '$username' has NO sudo or docker privileges."
echo "Please ask the user to log out and log back in."
