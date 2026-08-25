#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Only root may modify users."
    exit 1
fi

read -rp "Enter username: " username

if ! id "$username" &>/dev/null; then
    echo "User '$username' does not exist."
    exit 1
fi

echo
echo "User '$username' currently has:"
id "$username"
echo

# Remove user from sudo group
if groups "$username" | grep -qw sudo; then
    if gpasswd -d "$username" sudo; then
        echo "Removed '$username' from sudo group."
    else
        echo "Failed to remove '$username' from sudo group."
        exit 1
    fi
else
    echo "'$username' is not a member of the sudo group."
fi

echo
read -rp "Do you want to add '$username' to the docker group? [y/N]: " add_docker

if [[ "$add_docker" =~ ^[Yy]$ ]]; then
    if usermod -aG docker "$username"; then
        echo "Added '$username' to docker group."
    else
        echo "Failed to add '$username' to docker group."
        exit 1
    fi
fi

echo
read -rp "Do you want to DELETE user '$username' and their home directory? [y/N]: " delete_user

if [[ "$delete_user" =~ ^[Yy]$ ]]; then

    echo
    echo "WARNING: This will permanently delete:"
    echo "  - User account: $username"
    echo "  - Home directory: /home/$username"
    echo "  - User's local files"
    echo

    read -rp "Type the username '$username' to confirm deletion: " confirmation

    if [[ "$confirmation" == "$username" ]]; then
        if userdel -r "$username"; then
            echo
            echo "User '$username' and home directory were deleted successfully."
        else
            echo
            echo "Failed to delete user '$username'."
            exit 1
        fi
    else
        echo "Deletion cancelled."
    fi
fi

echo
if id "$username" &>/dev/null; then
    echo "Current groups for '$username':"
    id "$username"
    echo
    echo "Please ask the user to log out and log back in."
fi
