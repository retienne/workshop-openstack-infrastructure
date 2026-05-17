#!/bin/bash
# Description: Prompts the user to select a workshop from the available options.
# Prints the selected workshop name to stdout so the Makefile can capture it.
#
# Arguments:
#   $1 - DEFAULT_WS: The default workshop name (or the one passed via WORKSHOP=).
#   $2 - AVAILABLE_WS: A space-separated list of available workshop repositories.
#   $3 - IS_CLI_WORKSHOP: The Make origin of the WORKSHOP variable.
#   $4 - IS_CLI_workshop: The Make origin of the lower-case 'workshop' variable.
#   $5 - CLI_workshop_VAL: The value of the lower-case 'workshop' variable.

DEFAULT_WS="$1"
AVAILABLE_WS="$2"
IS_CLI_WORKSHOP="$3"
IS_CLI_workshop="$4"
CLI_workshop_VAL="$5"

# If passed via command line, skip the prompt and return it directly
if [ "$IS_CLI_WORKSHOP" = "command line" ]; then
    echo "$DEFAULT_WS"
    exit 0
fi

if [ "$IS_CLI_workshop" = "command line" ] && [ -n "$CLI_workshop_VAL" ]; then
    echo "$CLI_workshop_VAL"
    exit 0
fi

echo "Available workshops:" >&2
i=1
for w in $AVAILABLE_WS; do
    echo "  $i) $w" >&2
    i=$((i + 1))
done

read -p "Which workshop repo? (Enter number or name, default: $DEFAULT_WS): " user_workshop < /dev/tty

i=1
FOUND=""
for w in $AVAILABLE_WS; do
    if [ "$user_workshop" = "$i" ]; then
        FOUND="$w"
    fi
    i=$((i + 1))
done

if [ -n "$FOUND" ]; then
    echo "$FOUND"
else
    echo "${user_workshop:-$DEFAULT_WS}"
fi
