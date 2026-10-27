#!/bin/bash
# Used for manual operations

SCRIPTDIR=$(realpath "$(dirname "$0")")
set -a
. "$SCRIPTDIR/.env"
set +a

restic "$@"
