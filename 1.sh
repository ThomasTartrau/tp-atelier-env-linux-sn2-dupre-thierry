#!/bin/bash

# Variables for the IP addresses of the machines
WEB=john@192.168.122.145
BDD=john@192.168.122.2
# Variable for the password of the user root
SUDOPASS="root"

ssh_jobs()
{
    # Add the public key to the authorized_keys file on the remote machine
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $WEB

    # Disable the password authentication on the remote machine and restart the sshd service
    ssh -tt $WEB "echo $SUDOPASS | sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
}