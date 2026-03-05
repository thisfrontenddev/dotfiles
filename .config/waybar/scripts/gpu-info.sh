#!/bin/bash
# GPU usage + temp with detailed tooltip and top processes

data=$(nvidia-smi --query-gpu=utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder,utilization.jpeg,temperature.gpu,power.draw,clocks.current.graphics,clocks.current.memory,memory.used,memory.total,fan.speed --format=csv,noheader,nounits 2>/dev/null)

IFS=', ' read -r gpu_util mem_util enc dec jpeg temp power gfx_clk mem_clk mem_used mem_total fan <<< "$data"

tooltip="GPU Usage: ${gpu_util}%\n"
tooltip+="Memory Usage: ${mem_util}%\n"
tooltip+="Encoder: ${enc}%\n"
tooltip+="Decoder: ${dec}%\n"
tooltip+="JPEG: ${jpeg}%\n"
tooltip+="───────────────\n"
tooltip+="Temp: ${temp}°C\n"
tooltip+="Power: ${power}W\n"
tooltip+="Fan: ${fan}%\n"
tooltip+="───────────────\n"
tooltip+="GFX Clock: ${gfx_clk} MHz\n"
tooltip+="MEM Clock: ${mem_clk} MHz\n"
tooltip+="VRAM: ${mem_used}/${mem_total} MiB\n"
tooltip+="───────────────\n"

# Top GPU processes with usage breakdown
procs=$(nvidia-smi pmon -c 1 -s um 2>/dev/null | grep -v '^#' | sort -k4 -rn | head -5)
if [[ -n "$procs" ]]; then
    tooltip+="          SM  MEM  ENC  DEC   VRAM\n"
    while read -r gpu pid type sm mem enc dec jpg ofa fb ccpm cmd rest; do
        [[ -z "$pid" || "$pid" == "-" ]] && continue
        sm=${sm//-/0}; mem=${mem//-/0}; enc=${enc//-/0}; dec=${dec//-/0}; fb=${fb//-/0}
        line=$(printf "%-8s %3s%% %3s%% %3s%% %3s%% %4sM" "$cmd" "$sm" "$mem" "$enc" "$dec" "$fb")
        tooltip+="${line}\n"
    done <<< "$procs"
else
    tooltip+="No GPU processes"
fi

printf '{"text": "%s%% %s°C", "tooltip": "%s"}' "$gpu_util" "$temp" "$tooltip"
