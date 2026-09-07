#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Only root may create users or modify user privileges."
    exit 1
fi

read -rp "Enter username: " username

if id "$username" &>/dev/null; then
    echo "User '$username' already exists."
    exit 1
fi

# Create standard user with a home directory and Bash shell
useradd -m -s /bin/bash "$username"

if [[ $? -ne 0 ]]; then
    echo "Failed to create user '$username'."
    exit 1
fi

# Set password
echo "Set password for '$username':"
passwd "$username"

if [[ $? -ne 0 ]]; then
    echo "Failed to set password."
    exit 1
fi

# Add user to docker group
usermod -aG docker "$username"

if [[ $? -ne 0 ]]; then
    echo "Failed to add '$username' to docker group."
    exit 1
fi

echo
echo "User '$username' created successfully."
echo "User '$username' has been added to the docker group."
echo
echo "The user is NOT a sudo user."
echo "Ask the user to log out and log back in."
echo
echo "Verify with:"
echo "    id $username"
echo "    groups $username"
