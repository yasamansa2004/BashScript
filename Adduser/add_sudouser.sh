#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Only root may add a user to the system."
    exit 1
fi

read -rp "Enter username: " username
read -rsp "Enter password: " password
echo

if id "$username" &>/dev/null; then
    echo "User '$username' already exists!"
    exit 1
fi

useradd -m -s /bin/bash -G sudo "$username"

if [[ $? -ne 0 ]]; then
    echo "Failed to create user."
    exit 1
fi

echo "$username:$password" | chpasswd

echo "User '$username' has been added with sudo privileges."
