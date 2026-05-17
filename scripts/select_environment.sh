#!/bin/bash
# Description: Connects via SSH to fetch available docker-compose environments
# and prompts the user to select one. Prints the choice to stdout.
#
# Arguments:
#   $1 - IP: The IP address of the remote OpenStack instance.
#   $2 - PRIVATE_KEY: Path to the SSH private key for authentication.
#   $3 - WORKSHOP: The name of the workshop repository (used to locate environments).
#   $4 - EXTRA_KEY: (Optional) A key for an additional menu option (e.g., 'all').
#   $5 - EXTRA_TEXT: (Optional) Display text for the additional menu option.

IP="$1"
PRIVATE_KEY="$2"
WORKSHOP="$3"
EXTRA_KEY="$4"
EXTRA_TEXT="$5"

GITHUB_OWNER=$(grep '^github_owner:' ansible/group_vars/all.yml | awk '{print $2}' | tr -d '"' | tr -d "'")
if [ -z "$GITHUB_OWNER" ]; then GITHUB_OWNER="gschmutz"; fi

echo "Fetching available environments for $WORKSHOP..." >&2
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PRIVATE_KEY" ubuntu@"$IP" "if [ ! -d /home/ubuntu/$WORKSHOP ]; then git clone https://github.com/$GITHUB_OWNER/$WORKSHOP.git /home/ubuntu/$WORKSHOP --depth 1 >/dev/null 2>&1 || true; fi"

FOLDERS=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$PRIVATE_KEY" ubuntu@"$IP" "find /home/ubuntu/$WORKSHOP/00-environment -mindepth 2 -maxdepth 2 -type f \( -name docker-compose.yml -o -name docker-compose.yaml \) -exec dirname {} \; 2>/dev/null | xargs -n 1 basename 2>/dev/null | sort -u" 2>/dev/null || echo "")

if [ -z "$FOLDERS" ]; then
    echo "No valid environments (with docker-compose) found in 00-environment folder for $WORKSHOP." >&2
    if [ -n "$EXTRA_KEY" ]; then
        read -p "Enter environment folder name manually (or '$EXTRA_KEY' to $EXTRA_TEXT): " ENV_VAL < /dev/tty
    else
        read -p "Enter environment folder name manually: " ENV_VAL < /dev/tty
    fi
else
    echo "Available environments:" >&2
    i=1
    for f in $FOLDERS; do
        echo "  $i) $f" >&2
        i=$((i + 1))
    done
    
    if [ -n "$EXTRA_KEY" ]; then
        echo "  - $EXTRA_KEY ($EXTRA_TEXT)" >&2
    fi

    read -p "Which environment folder do you want to select? (Enter number or name): " user_env < /dev/tty
    
    if [ -n "$EXTRA_KEY" ] && [ "$user_env" = "$EXTRA_KEY" ]; then
        ENV_VAL="$EXTRA_KEY"
    else
        ENV_VAL=""
        i=1
        for f in $FOLDERS; do
            if [ "$user_env" = "$i" ]; then
                ENV_VAL="$f"
            fi
            i=$((i + 1))
        done
        if [ -z "$ENV_VAL" ]; then ENV_VAL="$user_env"; fi
    fi
fi

if [ -z "$ENV_VAL" ]; then 
    echo "Environment is required." >&2
    exit 1
fi

echo "$ENV_VAL"
