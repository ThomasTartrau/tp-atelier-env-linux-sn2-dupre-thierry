#!/bin/bash

# Local ssh public key
LOCAL_SSH_PUBLIC_KEY="~/.ssh/id_ed25519.pub"

main() {
    WEB_MACHINES=$(./get_machines.sh web)

    if [ -z "$WEB_MACHINES" ]; then
        echo "No web machines found exiting"
        exit 1
    fi

    BDD_MACHINES=$(./get_machines.sh bdd)

    if [ -z "$BDD_MACHINES" ]; then
        echo "No bdd machines found exiting"
        exit 1
    fi

    SUDOPASS=$(whiptail --passwordbox "Please enter your root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)


    web_rules=(
        "-A INPUT -i lo -j ACCEPT"
        "-A OUTPUT -o lo -j ACCEPT"
        "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
        "-A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        "-A INPUT -m conntrack --ctstate INVALID -j DROP"
        "-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"
        "-A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        "-A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"
        "-A OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        "-A INPUT -j DROP"
    )

    bdd_rules=(
        "-A INPUT -i lo -j ACCEPT"
        "-A OUTPUT -o lo -j ACCEPT"
        "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
        "-A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        "-A INPUT -m conntrack --ctstate INVALID -j DROP"
        "-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"
        "-A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        "-A OUTPUT -p tcp --sport 3306 -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        "-A INPUT -j DROP"
    )

    for MACHINE in $WEB_MACHINES; do
        IP_MACHINE=$(echo $MACHINE | cut -d'@' -f2)
        bdd_rules+=("-A INPUT -p tcp -s $IP_MACHINE --dport 3306 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT")

        ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S apt update && echo $SUDOPASS | sudo -S DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y"

        ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S iptables -F && echo $SUDOPASS | sudo -S iptables -X"

        for rule in "${web_rules[@]}"; do
            ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S iptables $rule"
        done

        ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S bash -c 'iptables-save > /etc/iptables/rules.v4' && echo $SUDOPASS | sudo -S systemctl restart iptables"
    done

    for MACHINE in $BDD_MACHINES; do
        ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S apt update && echo $SUDOPASS | sudo -S DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y"

        ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S iptables -F && echo $SUDOPASS | sudo -S iptables -X"

        for rule in "${bdd_rules[@]}"; do
            ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S iptables $rule"
        done

        ssh -i $LOCAL_SSH_PUBLIC_KEY -tt $MACHINE "echo $SUDOPASS | sudo -S bash -c 'iptables-save > /etc/iptables/rules.v4' && echo $SUDOPASS | sudo -S systemctl restart iptables"
    done
}

main
