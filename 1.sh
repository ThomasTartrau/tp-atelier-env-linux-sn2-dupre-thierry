#!/bin/bash

# Variables for the IP addresses of the machines
WEB=john@192.168.122.145
BDD=john@192.168.122.2

# Variable for the password of the user root
SUDOPASS="root"

# Helper function to display the usage of the script
help()
{
    echo "Usage: ./script.sh [web|bdd|deploywp]"
}

deploy_web()
{
    # install apache2 and some php8
}

# Check if the user has provided minimum 1 argument
if [ $# -eq 0 ]; then
    help
    exit 1
fi

case $1 in
    "web")
        echo "Web server"
        ;;
    "bdd")
        echo "Database server"
        ;;
    "deploywp")
        echo "Deploy WordPress"
        ;;
    *)
        help
        ;;
esac








ssh_jobs()
{
    # Add the public key to the authorized_keys file on the remote machine
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $WEB

    # Disable the password authentication on the remote machine and restart the sshd service
    ssh -tt $WEB "echo $SUDOPASS | sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
}