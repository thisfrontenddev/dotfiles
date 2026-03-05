#!/bin/bash
# RAM usage with detailed tooltip and top processes

read -r total used free shared buffcache available <<< $(free -b | awk '/Mem:/ {print $2, $3, $4, $5, $6, $7}')

to_g() { awk "BEGIN {printf \"%.1f\", $1/1073741824}"; }

used_g=$(to_g "$used")
free_g=$(to_g "$free")
buffcache_g=$(to_g "$buffcache")
avail_g=$(to_g "$available")
shared_g=$(to_g "$shared")

tooltip="Used: ${used_g}G\n"
tooltip+="Available: ${avail_g}G\n"
tooltip+="Free: ${free_g}G\n"
tooltip+="Buff/Cache: ${buffcache_g}G\n"
tooltip+="Shared: ${shared_g}G\n"

# Swap
read -r sw_total sw_used sw_free <<< $(free -b | awk '/Swap:/ {print $2, $3, $4}')
sw_total_g=$(to_g "$sw_total")
sw_used_g=$(to_g "$sw_used")
tooltip+="───────────────\n"
tooltip+="Swap: ${sw_used_g}G / ${sw_total_g}G\n"

# Reserved memory (installed minus kernel-visible)
total_g_raw=$(awk "BEGIN {printf \"%.1f\", $total/1073741824}")
installed_g=$(awk "BEGIN {
    v = $total_g_raw
    split(\"8 16 32 64 128 256 512\", sizes)
    for (i in sizes) if (sizes[i]+0 >= v) { print sizes[i]; exit }
}")
reserved_g=$(awk "BEGIN {printf \"%.1f\", $installed_g - $total_g_raw}")
tooltip+="Reserved: ${reserved_g}G\n"

# Top 5 RAM-hungry processes
tooltip+="───────────────\n"
top_procs=$(ps -eo rss,comm --sort=-rss --no-headers | head -5 | awk '{printf "%6.0fM  %s\\n", $1/1024, $2}')
tooltip+="$top_procs"

printf '{"text": "%sG/%sG", "tooltip": "%s"}' "$used_g" "$installed_g" "$tooltip"
