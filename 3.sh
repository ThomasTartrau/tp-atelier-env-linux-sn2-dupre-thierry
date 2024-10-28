#!/bin/bash

PUBLIC_WEB_IP="192.168.121.3"
PRIVATE_WEB_IP="192.168.56.10"
WEB_USERNAME="john"

PUBLIC_BDD_IP="192.168.121.81"
PRIVATE_BDD_IP="192.168.56.11"
BDD_USERNAME="john"

SUDOPASS="root"

IS_VAGRANT=true

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
    "-A INPUT -p tcp -s $PRIVATE_WEB_IP --dport 3306 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"
    "-A OUTPUT -p tcp --sport 3306 -m conntrack --ctstate ESTABLISHED -j ACCEPT"
    "-A INPUT -j DROP"
)

main() {
    if [ "$IS_VAGRANT" = true ]; then
        vagrant ssh web -c "echo $SUDOPASS | sudo -S apt update && echo $SUDOPASS | sudo -S apt install iptables-persistent -y"
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S apt update && echo $SUDOPASS | sudo -S apt install iptables-persistent -y"

        vagrant ssh web -c "echo $SUDOPASS | sudo -S iptables -F && echo $SUDOPASS | sudo -S iptables -X"
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S iptables -F && echo $SUDOPASS | sudo -S iptables -X"

        for rule in "${web_rules[@]}"; do
            vagrant ssh web -c "echo $SUDOPASS | sudo -S iptables $rule"
        done

        for rule in "${bdd_rules[@]}"; do
            vagrant ssh bdd -c "echo $SUDOPASS | sudo -S iptables $rule"
        done

        # Sauvegarde des règles
        vagrant ssh web -c "echo $SUDOPASS | sudo -S iptables-save > /etc/iptables/rules.v4 && echo $SUDOPASS | sudo -S systemctl restart iptables-persistent"
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S iptables-save > /etc/iptables/rules.v4 && echo $SUDOPASS | sudo -S systemctl restart iptables-persistent"
    else
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo apt update && sudo apt install iptables-persistent -y"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo apt update && sudo apt install iptables-persistent -y"

        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo iptables -F && sudo iptables -X"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo iptables -F && sudo iptables -X"

        for rule in "${web_rules[@]}"; do
            echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo iptables $rule"
        done

        for rule in "${bdd_rules[@]}"; do
            echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo iptables $rule"
        done

        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo iptables-save > /etc/iptables/rules.v4 && sudo systemctl restart iptables-persistent"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo iptables-save > /etc/iptables/rules.v4 && sudo systemctl restart iptables-persistent"
    fi
}

main
