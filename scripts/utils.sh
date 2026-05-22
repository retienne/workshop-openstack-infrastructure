#!/bin/bash
# Description: Small utility functions for the Makefile.
#
# Arguments:
#   $1 - COMMAND: The utility subcommand (update_hosts, setup_ssh, status, open_browser).
#   $2 - ARG1: Varies based on command (IP address or Private Key Path).
#   $3 - ARG2: Varies based on command (Private Key Path).
#   $4 - ARG3: Varies based on command (VM ID for status).

COMMAND="$1"

case "$COMMAND" in
    update_hosts)
        IP="$2"
        if [ -z "$IP" ]; then
            echo "Failed to get instance IP from Terraform output"
            exit 1
        fi
        echo "Updating /etc/hosts with $IP..."
        sudo sed -i.bak '/dataplatform\|nosqlplatform/d' /etc/hosts
        echo "$IP dataplatform nosqlplatform" | sudo tee -a /etc/hosts
        ;;
        
    setup_ssh)
        PRIVATE_KEY="$2"
        if [ ! -f "$PRIVATE_KEY" ]; then
            echo "Generating SSH key pair at $PRIVATE_KEY..."
            mkdir -p "$(dirname "$PRIVATE_KEY")"
            ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY" -N ""
        else
            echo "SSH key pair already exists at $PRIVATE_KEY."
        fi
        ;;
        
    status)
        IP="$2"
        PRIVATE_KEY="$3"
        VM_ID="$4"
        echo "=== OpenStack VM Status ==="
        if command -v openstack >/dev/null 2>&1; then
            if [ -n "$VM_ID" ]; then
                VM_STATUS=$(openstack server show "$VM_ID" -c status -f value 2>/dev/null || echo "Unknown")
                echo "$VM_STATUS"
                if [ "$VM_STATUS" = "SHUTOFF" ]; then
                    echo "💡 Tip: The VM is paused. You can restart it by running 'make unpause'."
                fi
                echo "=== Cinder Volume Status ==="
                VOL_INFO=$(openstack server show "$VM_ID" -c volumes_attached -f value 2>/dev/null || echo "")
                VOL_ID=$(echo "$VOL_INFO" | grep -oE "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}" | head -n 1)
                if [ -n "$VOL_ID" ]; then
                    VOL_STATUS=$(openstack volume show "$VOL_ID" -c status -f value 2>/dev/null || echo "Unknown")
                    if [ "$VOL_STATUS" = "in-use" ]; then
                        echo "in-use (Exists and is mounted/used by VM)"
                    elif [ "$VOL_STATUS" = "available" ]; then
                        echo "available (Exists but it's not mounted)"
                    else
                        echo "$VOL_STATUS"
                    fi
                else
                    echo "Does not exist."
                fi
            else
                echo "Unknown (VM ID not found in Terraform)"
                echo "=== Cinder Volume Status ==="
                echo "Does not exist."
            fi
        else
            echo "Unknown (openstack CLI not installed)"
        fi
        echo "=== Disk Status ==="
        if [ -z "$IP" ]; then
            echo "Failed to get instance IP from Terraform."
        else
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i "$PRIVATE_KEY" ubuntu@"$IP" 'df -h /' 2>/dev/null || echo "VM is offline or unreachable."
        fi
        echo "=== Docker Status ==="
        if [ -z "$IP" ]; then
            echo "Failed to get instance IP from Terraform."
        else
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i "$PRIVATE_KEY" ubuntu@"$IP" 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"' 2>/dev/null || echo "VM is offline or unreachable."
        fi
        ;;
        
    open_browser)
        IP="$2"
        if [ -z "$IP" ]; then
            echo "Failed to get instance IP from Terraform."
            exit 1
        fi
        URL="http://$IP"
        echo "Opening $URL ..."
        if command -v xdg-open >/dev/null; then
            xdg-open "$URL"
        elif command -v open >/dev/null; then
            open "$URL"
        else
            echo "Could not detect web browser. Please open $URL manually."
        fi
        ;;
        
    *)
        echo "Unknown utils command: $COMMAND"
        exit 1
        ;;
esac
