#!/bin/bash
# Description: Manages the systemd-based autodestruction lifecycle for ephemeral environments.
#
# Arguments:
#   $1 - COMMAND: The autodestroy subcommand (timer, shutdown, status, attach, reschedule, cancel).
#   $2 - TTL: (Optional) Time-to-live string (e.g., '4h', '30m') used for timer and reschedule commands.
#   $3 - PWD_DIR: (Optional) The working directory to execute the destruction command from.

COMMAND="$1"
TTL="$2"
PWD_DIR="$3"

UNIT_NAME="workshop-autodestroy"

build_os_env_args() {
    OS_ENV_ARGS=()
    while IFS= read -r var; do
        OS_ENV_ARGS+=("--setenv=$var")
    done < <(env | grep "^OS_")
}

case "$COMMAND" in
    timer)
        if systemctl --user is-active --quiet "$UNIT_NAME"; then
            echo "An auto-destruction timer is already running! Use 'make autodestroy-status'."
            exit 1
        fi
        
        VALUE="${TTL%%[a-zA-Z]*}"
        UNIT="${TTL##*[0-9]}"
        case "$UNIT" in
            h) SECS=$((VALUE * 3600)) ;;
            m) SECS=$((VALUE * 60)) ;;
            s|"") SECS=$VALUE ;;
            d) SECS=$((VALUE * 86400)) ;;
            *) SECS=$VALUE ;;
        esac
        
        END_TIME=$(( $(date +%s) + SECS ))
        echo "$END_TIME" > .autodestroy_end_time
        
        build_os_env_args
        
        systemctl --user reset-failed "$UNIT_NAME" 2>/dev/null || true
        
        if ! ERR_MSG=$(systemd-run --user --unit="$UNIT_NAME" --working-directory="$PWD_DIR" \
            "${OS_ENV_ARGS[@]}" \
            --property="ExecStop=/usr/bin/make destroy" \
            /bin/bash -c "while [ \$(date +%s) -lt \$(cat .autodestroy_end_time) ]; do sleep 5; done" 2>&1); then
            echo "❌ Failed to start the autodestroy background service."
            echo "Error: $ERR_MSG"
            exit 1
        fi
            
        echo "============================================================"
        echo "⚠️  TIMER DESTRUCTION SCHEDULED"
        echo "⚠️  The infrastructure will self-destruct in $TTL or on shutdown."
        echo "⚠️  Use 'make autodestroy-status' to check time remaining."
        echo "⚠️  Use 'make autodestroy-cancel' to abort."
        echo "============================================================"
        ;;
        
    shutdown)
        if systemctl --user is-active --quiet "$UNIT_NAME"; then
            echo "An auto-destruction timer is already running!"
            exit 1
        fi
        
        echo 2147483647 > .autodestroy_end_time
        build_os_env_args
        
        systemctl --user reset-failed "$UNIT_NAME" 2>/dev/null || true
        
        if ! ERR_MSG=$(systemd-run --user --unit="$UNIT_NAME" --working-directory="$PWD_DIR" \
            "${OS_ENV_ARGS[@]}" \
            --property="ExecStop=/usr/bin/make destroy" \
            /bin/bash -c "sleep infinity" 2>&1); then
            echo "❌ Failed to start the autodestroy background service."
            echo "Error: $ERR_MSG"
            exit 1
        fi
            
        echo "============================================================"
        echo "⚠️  SHUTDOWN DESTRUCTION SCHEDULED"
        echo "⚠️  The infrastructure will self-destruct on shutdown/logout."
        echo "============================================================"
        ;;
        
    status)
        if ! systemctl --user is-active --quiet "$UNIT_NAME"; then
            echo "No auto-destruction is currently running."
            exit 0
        fi
        NOW=$(date +%s)
        END_TIME=$(cat .autodestroy_end_time)
        REMAINING=$((END_TIME - NOW))
        if [ "$REMAINING" -lt 0 ]; then REMAINING=0; fi
        
        if [ "$REMAINING" -gt 31536000 ]; then
            echo "⏳ Ephemeral deployment active. Waiting for shutdown/logout."
        else
            printf "⏳ Ephemeral deployment active. Time remaining: %02d:%02d:%02d\n" $((REMAINING/3600)) $(( (REMAINING%3600)/60 )) $((REMAINING%60))
        fi
        ;;
        
    attach)
        if ! systemctl --user is-active --quiet "$UNIT_NAME"; then
            echo "No auto-destruction is currently running."
            exit 0
        fi
        echo "Press Ctrl+C to detach (this will NOT destroy the infrastructure)."
        while systemctl --user is-active --quiet "$UNIT_NAME"; do
            NOW=$(date +%s)
            if [ ! -f .autodestroy_end_time ]; then break; fi
            END_TIME=$(cat .autodestroy_end_time)
            REMAINING=$((END_TIME - NOW))
            if [ "$REMAINING" -lt 0 ]; then REMAINING=0; fi
            if [ "$REMAINING" -gt 31536000 ]; then
                printf "\r⏳ Waiting for shutdown...   "
            else
                printf "\r⏳ Time until self-destruct: %02d:%02d:%02d   " $((REMAINING/3600)) $(( (REMAINING%3600)/60 )) $((REMAINING%60))
            fi
            sleep 1
        done
        echo -e "\nDestruction triggered or completed."
        ;;
        
    reschedule)
        if ! systemctl --user is-active --quiet "$UNIT_NAME"; then
            echo "No auto-destruction is currently running."
            exit 1
        fi
        VALUE="${TTL%%[a-zA-Z]*}"
        UNIT="${TTL##*[0-9]}"
        case "$UNIT" in
            h) SECS=$((VALUE * 3600)) ;;
            m) SECS=$((VALUE * 60)) ;;
            s|"") SECS=$VALUE ;;
            d) SECS=$((VALUE * 86400)) ;;
            *) SECS=$VALUE ;;
        esac
        END_TIME=$(( $(date +%s) + SECS ))
        echo "$END_TIME" > .autodestroy_end_time
        echo "Ephemeral deployment rescheduled to terminate in $TTL."
        ;;
        
    cancel)
        if ! systemctl --user is-active --quiet "$UNIT_NAME"; then
            echo "No auto-destruction is currently running."
            exit 0
        fi
        echo "Canceling auto-destruction and triggering destruction..."
        systemctl --user stop "$UNIT_NAME"
        ;;
        
    *)
        echo "Unknown autodestroy command: $COMMAND"
        exit 1
        ;;
esac
