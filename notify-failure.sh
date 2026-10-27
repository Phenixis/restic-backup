#!/bin/bash
# Called by restic-failure-mail@.service when a unit fails: mails the end of its journal.
set -uo pipefail
cd "$(dirname "$0")"
unit=${1:?unit name}
{
  echo "The unit $unit failed on $(hostname) at $(date -Is)."
  echo
  echo "Last log lines (journalctl --user -u $unit):"
  journalctl --user -u "$unit" --no-pager -n 40 | cut -c1-300
} | ./notify-mail.sh "[mdserv] $unit FAILED"
