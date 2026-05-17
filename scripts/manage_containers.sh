#!/bin/bash
# Description: Handles checking, prompting, and stopping running containers.
#
# Arguments:
#   $1 - ACTION: The operation to perform ('check_and_stop' or 'stop_all').
#   $2 - IP: The IP address of the remote OpenStack instance.
#   $3 - PRIVATE_KEY: Path to the SSH private key for authentication.

ACTION="$1"
IP="$2"
PRIVATE_KEY="$3"

SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $PRIVATE_KEY ubuntu@$IP"

if [ "$ACTION" = "check_and_stop" ]; then
    echo "Checking for running containers on $IP..."
    RUNNING=$($SSH_CMD "docker ps -q" 2>/dev/null || true)
    
    if [ -n "$RUNNING" ]; then
        read -p "🚨 Containers are already running! To avoid conflicts, we should stop them. Stop existing environments? [Y/n] " ans < /dev/tty
        if [ -z "$ans" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
            echo "Stopping all existing environments..."
            $SSH_CMD "find /home/ubuntu/*/00-environment -mindepth 1 -maxdepth 1 -type d -exec sh -c 'cd \"{}\" && sudo docker compose down' \;" 2>/dev/null || true
        else
            read -p "⚠️  Are you absolutely sure you want to run multiple environments simultaneously? This may cause port conflicts. Continue? [y/N] " force_ans < /dev/tty
            if [ "$force_ans" != "y" ] && [ "$force_ans" != "Y" ]; then
                echo "Aborting."
                exit 1
            fi
        fi
    fi

elif [ "$ACTION" = "stop_all" ]; then
    echo "Stopping all environments..."
    $SSH_CMD "find /home/ubuntu/*/00-environment -mindepth 1 -maxdepth 1 -type d -exec sh -c 'cd \"{}\" && sudo docker compose down' \;" 2>/dev/null || true
else
    echo "Unknown action: $ACTION"
    exit 1
fi
