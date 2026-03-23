#!/bin/bash
# GPU usage + temp with detailed tooltip
# Supports NVIDIA (nvidia-smi) and AMD iGPU (amdgpu sysfs)

# Use NVIDIA if it's the primary display GPU (check if DP-6/HDMI-A-2 exist under nvidia card)
# When on iGPU, displays are on amdgpu (DP-1/HDMI-A-1)
NVIDIA_HAS_DISPLAY=false
for conn in /sys/class/drm/card*/; do
    driver=$(readlink "${conn}device/driver" 2>/dev/null | xargs basename 2>/dev/null)
    if [[ "$driver" == "nvidia" ]]; then
        for status in "${conn}"*/status; do
            [[ "$(cat "$status" 2>/dev/null)" == "connected" ]] && NVIDIA_HAS_DISPLAY=true
        done
    fi
done

if [[ "$NVIDIA_HAS_DISPLAY" == "true" ]] && command -v nvidia-smi &>/dev/null; then
    # ── NVIDIA dGPU ──
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
else
    # ── AMD iGPU (amdgpu sysfs) ──
    CARD=""
    for c in /sys/class/drm/card[0-9]; do
        driver=$(readlink "${c}/device/driver" 2>/dev/null | xargs basename 2>/dev/null)
        [[ "$driver" == "amdgpu" ]] && CARD="$c" && break
    done
    [[ -z "$CARD" ]] && { printf '{"text": "N/A", "tooltip": "No AMD GPU found"}'; exit; }
    HWMON=$(find "${CARD}/device/hwmon" -maxdepth 1 -name "hwmon*" 2>/dev/null | head -1)

    # GPU utilization
    gpu_util=$(cat "${CARD}/device/gpu_busy_percent" 2>/dev/null || echo "?")

    # Read all amdgpu sensor data in one call
    read -r temp power < <(sensors -j 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k, v in d.items():
    if 'amdgpu' in k.lower():
        temp = int(v.get('edge', {}).get('temp1_input', 0))
        power = v.get('PPT', {}).get('power1_input', 0)
        print(temp, f'{power:.1f}')
        sys.exit()
print('? 0.0')
" 2>/dev/null)

    # Clocks
    gfx_clk=$(grep '\*' "${CARD}/device/pp_dpm_sclk" 2>/dev/null | awk '{print $2}' | tr -d 'Mhz')
    mem_clk=$(grep '\*' "${CARD}/device/pp_dpm_mclk" 2>/dev/null | awk '{print $2}' | tr -d 'Mhz')

    # VRAM
    mem_used_raw=$(cat "${CARD}/device/mem_info_vram_used" 2>/dev/null || echo "0")
    mem_total_raw=$(cat "${CARD}/device/mem_info_vram_total" 2>/dev/null || echo "0")
    mem_used=$((mem_used_raw / 1048576))
    mem_total=$((mem_total_raw / 1048576))

    tooltip="GPU Usage: ${gpu_util}%\n"
    tooltip+="Temp: ${temp}°C\n"
    tooltip+="Power: ${power}W\n"
    tooltip+="───────────────\n"
    tooltip+="GFX Clock: ${gfx_clk} MHz\n"
    tooltip+="MEM Clock: ${mem_clk} MHz\n"
    tooltip+="VRAM: ${mem_used}/${mem_total} MiB"

    printf '{"text": "%s%% %s°C", "tooltip": "%s"}' "$gpu_util" "$temp" "$tooltip"
fi
