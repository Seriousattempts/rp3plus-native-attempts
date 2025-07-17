#!/bin/sh

# Log firmware loading events
log() {
    logger -p daemon.info -t firmware "$@"
}

# Function to handle errors
load_error() {
    log "Failed to load $FIRMWARE for $DEVPATH"
    # Signal failure to the kernel
    echo "-1" > "/sys$DEVPATH/loading"
}

# Load firmware from a raw partition into a sysfs node
load_from_partition() {
    local partition_node="/dev/block/by-name/$1"
    log "Loading firmware from partition $partition_node"

    if [ ! -e "$partition_node" ]; then
        log "Error: Partition $partition_node not found."
        load_error
    else
        echo 1 > "/sys$DEVPATH/loading"
        cat "$partition_node" > "/sys$DEVPATH/data"
        echo 0 > "/sys$DEVPATH/loading"
        log "Firmware loading complete for $FIRMWARE"
    fi
}

log "Firmware request: $FIRMWARE for devpath $DEVPATH"

# Check if the kernel is requesting firmware loading
if [ -e "/sys$DEVPATH/loading" ]; then
    case "$FIRMWARE" in
        # Map kernel firmware name to device partition name
        sprd/wcnmodem.bin)      load_from_partition wcnmodem_a ;;
        sprd/gnssmodem.bin)     load_from_partition gnssmodem_a ;;
        sprd/l_modem.bin)       load_from_partition l_modem_a ;;
        sprd/l_deltanv.bin)     load_from_partition l_deltanv_a ;;
        sprd/l_fixnv.bin)       load_from_partition l_fixnv1_a ;; # Maps to l_fixnv1_a
        sprd/l_gdsp.bin)        load_from_partition l_gdsp_a ;;
        sprd/l_ldsp.bin)        load_from_partition l_ldsp_a ;;
        sprd/l_agdsp.bin)       load_from_partition l_agdsp_a ;;
        sprd/l_cdsp.bin)        load_from_partition l_cdsp_a ;;
        sprd/pm_sys.bin)        load_from_partition pm_sys_a ;;
        *)
            log "Unknown firmware requested: $FIRMWARE"
            load_error
            ;;
    esac
fi

