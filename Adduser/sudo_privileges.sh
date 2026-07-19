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

usermod -aG sudo "$username"

if [[ $? -eq 0 ]]; then
    echo "User '$username' has been granted sudo privileges."
else
    echo "Failed to grant sudo privileges."
fi
