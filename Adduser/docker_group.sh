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

usermod -aG sudo,docker "$username"

if [[ $? -eq 0 ]]; then
    echo "User '$username' has been added to the sudo and docker groups."
    echo "Please ask the user to log out and log back in."
else
    echo "Failed to update user groups."
    exit 1
fi
