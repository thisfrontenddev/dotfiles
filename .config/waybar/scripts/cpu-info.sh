#!/bin/bash
# CPU usage + temp with per-core tooltip (delta-based) and top processes

STAT_FILE="/tmp/cpu-stat-prev"

# Read current stats
declare -A cur
while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    cur[$name]="$line"
done < <(grep '^cpu' /proc/stat)

temp=$(sensors -j 2>/dev/null | jq -r '.["k10temp-pci-00c3"].Tctl.temp1_input // empty' | xargs printf "%.0f" 2>/dev/null || echo "?")

# Calculate delta if previous sample exists
if [[ -f "$STAT_FILE" ]]; then
    declare -A prev
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        prev[$name]="$line"
    done < "$STAT_FILE"

    # Total CPU
    read -r _ pu1 _ pu3 pu4 _ <<< "${prev[cpu]}"
    read -r _ cu1 _ cu3 cu4 _ <<< "${cur[cpu]}"
    du=$((cu1+cu3-pu1-pu3))
    dt=$((cu1+cu3+cu4-pu1-pu3-pu4))
    if ((dt > 0)); then
        total=$((du*100/dt))
    else
        total=0
    fi

    # Per-core
    tooltip="Temp: ${temp}°C\n───────────────\n"
    i=0
    while [[ -n "${cur[cpu$i]}" ]]; do
        read -r _ pu1 _ pu3 pu4 _ <<< "${prev[cpu$i]}"
        read -r _ cu1 _ cu3 cu4 _ <<< "${cur[cpu$i]}"
        du=$((cu1+cu3-pu1-pu3))
        dt=$((cu1+cu3+cu4-pu1-pu3-pu4))
        if ((dt > 0)); then
            usage=$((du*100/dt))
        else
            usage=0
        fi
        cores+=("$usage")
        i=$((i+1))
    done

    for ((j=0; j<${#cores[@]}; j+=4)); do
        line=""
        for ((k=j; k<j+4 && k<${#cores[@]}; k++)); do
            line+=$(printf "C%-2d %3s%%  " "$k" "${cores[$k]}")
        done
        tooltip+="${line}\n"
    done
else
    total=$(grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; printf "%.0f", u*100/t}')
    tooltip="Temp: ${temp}°C\n(sampling...)\n"
fi

# Save current sample
grep '^cpu' /proc/stat > "$STAT_FILE"

# Top 5 CPU-hungry processes
tooltip+="───────────────\n"
top_procs=$(top -bn1 -o %CPU | awk 'NR>7 && NR<=12 {printf "%5.1f%%  %s\\n", $9, $12}')
tooltip+="$top_procs"

printf '{"text": "%s%% %s°C", "tooltip": "%s"}' "$total" "$temp" "$tooltip"
