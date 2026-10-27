#!/bin/bash
# https://gist.github.com/iTrooz/712093480b3261698baec2f90fb4868b
# Called by crontab/systemd timer
set -e
trap 'on_exit $?' EXIT
start=$(date +%s%N)
on_exit() {
    status=$1
    if [ $status -eq 0 ]; then
        end=$(date +%s%N)
        duration_nanos=$((end - start))
        LC_NUMERIC=C # for printf decimal point
        duration=$(printf "%.1f\n" $(echo $duration_nanos/1000000000 | bc -l))
        msg="Time: ${duration}s, Size: ${human_size}"
        echo "Success: $msg"
    else
        echo "Failure: $status"
    fi
}

# Set working directory
cd "$(realpath $(dirname $0))"

# Load .env
set -a
. "$PWD/.env"
set +a

# Read paths from paths.txt, expand ~, and store as array
echo "Read paths to backup from paths.txt"
BACKUP_PATHS=()
while IFS= read -r line || [ -n "$line" ]; do
    [[ -z "$line" ]] && continue
    BACKUP_PATHS+=("$(eval echo $line)")
done < "paths.txt"
echo "Paths to backup (${#BACKUP_PATHS[@]}): ${BACKUP_PATHS[@]}"

# Create temporary folder for hooks data
rm -rf ./tmp
mkdir -p ./tmp

echo "Run hooks"
for hook in "./hooks/"*; do
    [ -x "$hook" ] && "$hook"
done

echo "Run restic backup"
backup_output="$(restic backup "${BACKUP_PATHS[@]}" --json)"

# Delete temporary folder
rm -rf ./tmp

echo "Parse backup summary and notify"
last_json=$(echo "$backup_output" | jq -s '.[-1]')
backup_time=$(echo "$last_json" | jq -r '.total_duration')
backup_time_rounded=$(LC_NUMERIC=C printf "%.2f" "$backup_time")
data_bytes=$(echo "$last_json" | jq -r '.total_bytes_processed')
human_size=$(numfmt --to=iec-i --suffix=B "$data_bytes")

echo "Forget old backups"
restic forget \
    --keep-daily $RESTIC_KEEP_DAILY \
    --keep-weekly $RESTIC_KEEP_WEEKLY \
    --keep-monthly $RESTIC_KEEP_MONTHLY \
    --keep-yearly $RESTIC_KEEP_YEARLY \
    --group-by tags --prune

if [ -f ".env.b2" ]; then
    echo "Replicate snapshots to offsite B2 repository"
    LOCAL_REPOSITORY="$RESTIC_REPOSITORY"
    LOCAL_PASSWORD="$RESTIC_PASSWORD"
    # RESTIC_PASSWORD/RESTIC_REPOSITORY take priority over --password-command/-r
    # if left set, which would point the copy's destination back at the local repo
    unset RESTIC_REPOSITORY RESTIC_PASSWORD
    set -a
    . "$PWD/.env.b2"
    set +a

    restic copy \
        --from-repo "$LOCAL_REPOSITORY" \
        --from-password-command "echo \"$LOCAL_PASSWORD\"" \
        -r "$B2_REPOSITORY" \
        --password-command 'echo "$B2_RESTIC_PASSWORD"'

    echo "Forget old backups (offsite)"
    restic -r "$B2_REPOSITORY" --password-command 'echo "$B2_RESTIC_PASSWORD"' forget \
        --keep-daily $RESTIC_KEEP_DAILY \
        --keep-weekly $RESTIC_KEEP_WEEKLY \
        --keep-monthly $RESTIC_KEEP_MONTHLY \
        --keep-yearly $RESTIC_KEEP_YEARLY \
        --group-by tags --prune
fi
