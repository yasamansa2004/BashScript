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
adduser "$username"

if [[ $? -ne 0 ]]; then
    echo "Failed to create user."
    exit 1
fi

# Add to docker group only
usermod -aG docker "$username"

if [[ $? -eq 0 ]]; then
    echo
    echo "User '$username' created successfully."
    echo "Groups:"
    id "$username"
    echo
    echo "User has Docker access but NO sudo group membership."
    echo "Ask the user to log out and log back in."
else
    echo "User was created, but failed to add Docker group."
    exit 1
fi
