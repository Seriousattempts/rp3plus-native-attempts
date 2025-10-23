#!/bin/sh
# ============================================================
# RC Parser & Executor for Alpine Linux (BusyBox ash)
# Version: 7.0 - PRODUCTION READY
# ============================================================

# CRITICAL FIX: Remove "set -e" - mount failures should NOT stop execution
# set -e  # REMOVED - causes script to exit on first error

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================
SYSTEM_ROOT="${SYSTEM_ROOT:-/system}"
VENDOR_ROOT="${VENDOR_ROOT:-/vendor}"
SYSTEM_EXT_ROOT="${SYSTEM_EXT_ROOT:-/system_ext}"
PRODUCT_ROOT="${PRODUCT_ROOT:-/product}"
DATA_ROOT="${DATA_ROOT:-/data}"

ALPINE_USER="${ALPINE_USER:-root}"

SERVICE_REGISTRY="/tmp/rc_services.db"
PROPERTY_REGISTRY="/tmp/rc_properties.db"
IMPORT_REGISTRY="/tmp/rc_imports.db"
TRIGGER_QUEUE="/tmp/rc_triggers.queue"

mkdir -p "$(dirname "$SERVICE_REGISTRY")" 2>/dev/null
touch "$SERVICE_REGISTRY" "$PROPERTY_REGISTRY" "$IMPORT_REGISTRY" "$TRIGGER_QUEUE" 2>/dev/null

LOGFILE="${LOGFILE:-/var/log/rc-parser.log}"
VERBOSE="${VERBOSE:-1}"
AUTO_START_SERVICES="${AUTO_START_SERVICES:-0}"

# ============================================================
# PROPERTY SYSTEM (FLAT FILE - ASH COMPATIBLE)
# ============================================================
init_properties() {
    cat > "$PROPERTY_REGISTRY" << 'EOF'
ro.vendor.ko.mount.point=/vendor/lib/modules
ro.hardware=ums512_1h10
ro.hardware.egl=mali
soc=ums512
ro.bionic.arch=arm64
dev.mnt.blk.data=dm-0
sys.usb.configfs=1
sys.usb.ffs.ready=1
sys.usb.config=adb
ro.boot.slot_suffix=_a
ro.bootmode=normal
wifi.interface=wlan0
apexd.status=activated
ro.serialno=0123456789ABCDEF
ro.boot.super_partition=super
sys.usb.controller=dwc3-gadget
ro.zygote=zygote64_32
EOF
}

get_property() {
    grep "^${1}=" "$PROPERTY_REGISTRY" 2>/dev/null | cut -d'=' -f2- | head -1
}

set_property() {
    sed -i "/^${1}=/d" "$PROPERTY_REGISTRY" 2>/dev/null || true
    echo "${1}=${2}" >> "$PROPERTY_REGISTRY"
    debug "setprop $1=$2"
}

# ============================================================
# LOGGING
# ============================================================
log() {
    local level="${1:-INFO}"
    shift
    echo "[$(date '+%H:%M:%S')] [$level] $*" | tee -a "$LOGFILE"
}

debug() { [ "$VERBOSE" = "1" ] && log "DEBUG" "$@"; }
error() { log "ERROR" "$@" >&2; }
warn() { log "WARN" "$@"; }

# ============================================================
# PROPERTY EXPANSION
# ============================================================
expand_properties() {
    local input="$1"
    local output="$input"
    local max_iter=20
    local iter=0
    
    while echo "$output" | grep -q '\${[^}]*}' && [ $iter -lt $max_iter ]; do
        local prop_expr=$(echo "$output" | grep -o '\${[^}]*}' | head -1)
        local prop_full=$(echo "$prop_expr" | sed 's/\${//; s/}$//')
        
        local prop_name=""
        local default_val=""
        
        if echo "$prop_full" | grep -q ':-'; then
            prop_name=$(echo "$prop_full" | sed 's/:-.*$//')
            default_val=$(echo "$prop_full" | sed 's/^[^:]*:-//')
        else
            prop_name="$prop_full"
        fi
        
        local prop_value="$(get_property "$prop_name")"
        
        [ -z "$prop_value" ] && prop_value="$default_val"
        
        output="${output//$prop_expr/$prop_value}"
        iter=$((iter + 1))
    done
    
    echo "$output"
}

# ============================================================
# TRIGGER CHECKING
# ============================================================
check_trigger_condition() {
    local trigger="$1"
    trigger=$(expand_properties "$trigger")
    
    if echo "$trigger" | grep -q "&&"; then
        echo "$trigger" | tr '&&' '\n' | while IFS= read -r cond; do
            cond=$(echo "$cond" | xargs)
            check_single_trigger "$cond" || echo "FAIL"
        done | grep -q "FAIL" && return 1 || return 0
    else
        check_single_trigger "$trigger"
    fi
}

check_single_trigger() {
    case "$1" in
        early-init|init|late-init|early-fs|fs|post-fs|late-fs|post-fs-data|zygote-start|boot|nonencrypted|charger|cali|factorytest|early-boot)
            return 0 ;;
        property:*)
            check_property_condition "$1" ;;
        *)
            return 0 ;;
    esac
}

check_property_condition() {
    local condition=$(echo "$1" | sed 's/^property://')
    
    local prop_key=$(echo "$condition" | cut -d'=' -f1)
    local operator="="
    local prop_value=$(echo "$condition" | cut -d'=' -f2-)
    
    if echo "$condition" | grep -q '!='; then
        prop_key=$(echo "$condition" | cut -d'!' -f1)
        prop_value=$(echo "$condition" | sed 's/^[^!]*!=//')
        operator="!="
    fi
    
    local actual_value="$(get_property "$prop_key")"
    
    if [ "$prop_value" = "*" ]; then
        [ -n "$actual_value" ] && return 0 || return 1
    elif [ "$prop_value" = '""' ] || [ "$prop_value" = "''" ]; then
        [ -z "$actual_value" ] && return 0 || return 1
    fi
    
    case "$operator" in
        "=") [ "$actual_value" = "$prop_value" ] && return 0 || return 1 ;;
        "!=") [ "$actual_value" != "$prop_value" ] && return 0 || return 1 ;;
    esac
}

# ============================================================
# USER/GROUP MAPPING
# ============================================================
map_android_user_to_alpine() {
    case "$1" in root) echo "root" ;; *) echo "$ALPINE_USER" ;; esac
}

map_android_group_to_alpine() {
    case "$1" in
        root) echo "root" ;;
        audio) echo "audio" ;;
        video) echo "video" ;;
        *) echo "root" ;;
    esac
}

# ============================================================
# COMMAND EXECUTORS
# ============================================================
exec_mkdir() {
    local path="$1"
    local mode="$2"
    local owner="$3"
    local group="$4"
    
    path=$(expand_properties "$path")
    
    [ -n "$path" ] && mkdir -p "$path" 2>/dev/null
    [ -n "$mode" ] && chmod "$mode" "$path" 2>/dev/null
    
    if [ -n "$owner" ] && [ -n "$group" ] && ! echo "$group" | grep -q "^encryption"; then
        chown "$(map_android_user_to_alpine "$owner"):$(map_android_group_to_alpine "$group")" "$path" 2>/dev/null
    fi
}

exec_chmod() {
    local mode="$1"
    local path=$(expand_properties "$2")
    [ -e "$path" ] && chmod "$mode" "$path" 2>/dev/null || debug "chmod skipped: $path"
}

exec_chown() {
    local owner="$1"
    local group="$2"
    local path="$3"
    
    if [ -z "$path" ]; then
        path="$group"
        if echo "$owner" | grep -q ":"; then
            group=$(echo "$owner" | cut -d: -f2)
            owner=$(echo "$owner" | cut -d: -f1)
        else
            group="$owner"
        fi
    fi
    
    path=$(expand_properties "$path")
    [ -e "$path" ] && chown "$(map_android_user_to_alpine "$owner"):$(map_android_group_to_alpine "$group")" "$path" 2>/dev/null
}

exec_write() {
    local path="$1"
    shift
    
    path=$(expand_properties "$path")
    local value="$*"
    value=$(expand_properties "$value")
    value=$(echo "$value" | sed 's/\\n/\n/g')
    
    printf "%s\n" "$value" > "$path" 2>/dev/null || warn "write failed: $path"
}

exec_setprop() {
    set_property "$1" "$(expand_properties "$2")"
}

exec_symlink() {
    ln -sf "$(expand_properties "$1")" "$(expand_properties "$2")" 2>/dev/null || debug "symlink failed"
}

exec_copy() {
    cp "$(expand_properties "$1")" "$(expand_properties "$2")" 2>/dev/null || debug "copy failed"
}

exec_rm() { rm -f "$(expand_properties "$1")" 2>/dev/null; }
exec_rmdir() { rmdir "$(expand_properties "$1")" 2>/dev/null; }

# CRITICAL FIX: Mount should continue on error, not exit
exec_mount() {
    local fstype="$1"
    local device=$(expand_properties "$2")
    local mountpoint=$(expand_properties "$3")
    shift 3
    
    mkdir -p "$mountpoint" 2>/dev/null
    
    local mount_opts=""
    for opt in "$@"; do
        if echo "$opt" | grep -qE '^(mode=|uid=|gid=|nodev|noexec|nosuid|ro|rw|remount)'; then
            mount_opts="${mount_opts:+$mount_opts,}$opt"
        fi
    done
    
    [ -n "$mount_opts" ] && mount_opts="-o $mount_opts"
    
    # CRITICAL: Don't fail on mount errors
    if mount -t "$fstype" $mount_opts "$device" "$mountpoint" 2>&1 | grep -v "already mounted" | grep -v "busy" | tee -a "$LOGFILE"; then
        debug "mount OK: $mountpoint"
    else
        debug "mount skipped: $mountpoint (already mounted or busy)"
    fi
    
    return 0  # Always return success
}

exec_insmod() {
    local module_path=$(expand_properties "$1")
    shift
    
    if [ ! -f "$module_path" ]; then
        local module_name=$(basename "$module_path")
        for alt in "$VENDOR_ROOT/lib/modules/$module_name"; do
            [ -f "$alt" ] && module_path="$alt" && break
        done
    fi
    
    if [ ! -f "$module_path" ]; then
        warn "Module not found: $module_path"
        return 0  # Don't fail, just warn
    fi
    
    log "INFO" "Loading: $(basename "$module_path")"
    if insmod "$module_path" "$@" 2>&1 | tee -a "$LOGFILE"; then
        debug "Module loaded: $(basename "$module_path")"
    else
        warn "Module load failed: $(basename "$module_path")"
    fi
    
    return 0  # Always continue
}

exec_export() { export "$1"="$(expand_properties "$2")"; }
exec_setrlimit() {
    case "$1" in
        nofile) ulimit -n "$3" 2>/dev/null ;;
        nice) ulimit -e "$3" 2>/dev/null ;;
        rtprio) ulimit -r "$3" 2>/dev/null ;;
    esac
}

exec_ifup() { ip link set "$1" up 2>/dev/null || debug "ifup skipped: $1"; }
exec_hostname() { hostname "$1" 2>/dev/null; }
exec_wait() {
    local path=$(expand_properties "$1")
    local timeout="${2:-5}"
    local elapsed=0
    
    while [ ! -e "$path" ] && [ $elapsed -lt $timeout ]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done
}

exec_trigger() { echo "$1" >> "$TRIGGER_QUEUE"; }

exec_start() {
    local service_name="$1"
    
    log "INFO" "Starting: $service_name"
    
    local service_info=$(grep "^$service_name|" "$SERVICE_REGISTRY" | head -1)
    
    if [ -z "$service_info" ]; then
        set_property "init.svc.$service_name" "stopped"
        return 0
    fi
    
    local binary=$(echo "$service_info" | cut -d'|' -f2)
    local args=$(echo "$service_info" | cut -d'|' -f3)
    local oneshot=$(echo "$service_info" | cut -d'|' -f6)
    local disabled=$(echo "$service_info" | cut -d'|' -f7)
    
    binary=$(expand_properties "$binary")
    
    if [ "$disabled" = "1" ]; then
        set_property "init.svc.$service_name" "stopped"
        return 0
    fi
    
    if [ ! -x "$binary" ]; then
        warn "Binary not found: $binary"
        set_property "init.svc.$service_name" "stopped"
        return 0
    fi
    
    export LD_LIBRARY_PATH="$VENDOR_ROOT/lib64:$VENDOR_ROOT/lib:$SYSTEM_ROOT/lib64:$SYSTEM_ROOT/lib"
    export PATH="$VENDOR_ROOT/bin:$SYSTEM_ROOT/bin:$PATH"
    
    set_property "init.svc.$service_name" "starting"
    
    if [ "$oneshot" = "1" ]; then
        $binary $args 2>&1 | tee -a "$LOGFILE" || warn "Service $service_name failed"
        set_property "init.svc.$service_name" "stopped"
    else
        $binary $args > "/var/log/${service_name}.log" 2>&1 &
        echo $! > "/var/run/${service_name}.pid" 2>/dev/null
        set_property "init.svc.$service_name" "running"
    fi
    
    return 0
}

exec_stop() {
    local service_name="$1"
    set_property "init.svc.$service_name" "stopping"
    
    [ -f "/var/run/${service_name}.pid" ] && kill $(cat "/var/run/${service_name}.pid") 2>/dev/null
    rm -f "/var/run/${service_name}.pid" 2>/dev/null
    pkill -f "$service_name" 2>/dev/null || true
    
    set_property "init.svc.$service_name" "stopped"
    return 0
}

exec_restart() { exec_stop "$1"; sleep 1; exec_start "$1"; }

exec_class_start() {
    local class_name="$1"
    log "INFO" "Starting class: $class_name"
    
    grep "|$class_name|" "$SERVICE_REGISTRY" 2>/dev/null | while IFS='|' read -r name rest; do
        exec_start "$name"
    done
    return 0
}

exec_class_stop() {
    grep "|$2|" "$SERVICE_REGISTRY" 2>/dev/null | while IFS='|' read -r name rest; do
        exec_stop "$name"
    done
    return 0
}

exec_class_reset() { exec_class_stop "$1"; exec_class_start "$1"; }

exec_exec() {
    local binary="$1"
    shift
    binary=$(expand_properties "$binary")
    "$binary" "$@" 2>&1 | tee -a "$LOGFILE" || warn "exec failed: $binary"
    return 0
}

exec_exec_start() { exec_start "$1"; }
exec_execstart() { exec_start "$1"; }

# Skipped commands
exec_mount_all() { debug "mount_all (skipped)"; }
exec_restorecon() { :; }
exec_restorecon_recursive() { :; }
exec_swapon_all() { :; }
exec_umount() { :; }

# ============================================================
# SERVICE PARSER
# ============================================================
parse_service_block() {
    local service_name="$1"
    local binary="$2"
    shift 2
    local binary_args="$*"
    
    local user="root"
    local group="root"
    local class="default"
    local oneshot=0
    local disabled=0
    
    debug "Parsing service: $service_name"
    
    local line
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/\t/    /g; s/^[[:space:]]*//; s/[[:space:]]*$//')
        
        [ -z "$line" ] || echo "$line" | grep -q '^#' && continue
        
        ! echo "$line" | grep -q '^[[:space:]]' && echo "$line" >> /tmp/rc_parser_pushback && break
        
        local cmd=$(echo "$line" | awk '{print $1}')
        local args=$(echo "$line" | cut -d' ' -f2-)
        
        case "$cmd" in
            class) class="$args" ;;
            user) user="$args" ;;
            group) group="$args" ;;
            oneshot) oneshot=1 ;;
            disabled) disabled=1 ;;
            *) debug "  $cmd: $args" ;;
        esac
    done
    
    echo "$service_name|$binary|$binary_args|$user|$group|$oneshot|$disabled|$class" >> "$SERVICE_REGISTRY"
    
    [ "$AUTO_START_SERVICES" = "1" ] && [ "$disabled" = "0" ] && exec_start "$service_name"
}

# ============================================================
# IMPORT HANDLER
# ============================================================
handle_import() {
    local import_path=$(expand_properties "$1")
    
    if [ -z "$import_path" ]; then
        warn "Empty import path from: $1"
        return 0
    fi
    
    grep -q "^${import_path}$" "$IMPORT_REGISTRY" 2>/dev/null && return 0
    echo "$import_path" >> "$IMPORT_REGISTRY"
    
    if echo "$import_path" | grep -q '\*'; then
        local dir=$(dirname "$import_path")
        local pattern=$(basename "$import_path")
        
        if [ -d "$dir" ]; then
            for file in $(ls "$dir"/$pattern 2>/dev/null | sort); do
                [ -f "$file" ] && parse_rc_file "$file"
            done
        fi
    else
        if [ -f "$import_path" ]; then
            parse_rc_file "$import_path"
        else
            debug "Import not found: $import_path"
        fi
    fi
    
    return 0
}

# ============================================================
# MAIN RC FILE PARSER
# ============================================================
parse_rc_file() {
    local rc_file="$1"
    
    if [ ! -f "$rc_file" ]; then
        warn "RC file not found: $rc_file"
        return 0
    fi
    
    log "INFO" "=== Parsing: $rc_file ==="
    
    local in_trigger_block=0
    local should_execute=1
    
    > /tmp/rc_parser_pushback
    
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | sed 's/\t/    /g')
        
        [ "$in_trigger_block" = "0" ] && case "$line" in \#*|"") continue ;; esac
        
        if echo "$line" | grep -q "^import "; then
            handle_import "$(echo "$line" | sed 's/^import[[:space:]]*//')"
            continue
        fi
        
        if echo "$line" | sed 's/^[[:space:]]*//' | grep -q "^service "; then
            in_trigger_block=0
            local clean_line=$(echo "$line" | sed 's/^[[:space:]]*//; s/^service[[:space:]]*//')
            local svc_name=$(echo "$clean_line" | awk '{print $1}')
            local svc_binary=$(echo "$clean_line" | awk '{print $2}')
            local svc_args=$(echo "$clean_line" | cut -d' ' -f3-)
            parse_service_block "$svc_name" "$svc_binary" $svc_args
            continue
        fi
        
        if echo "$line" | grep -q "^on "; then
            in_trigger_block=1
            local trigger=$(echo "$line" | sed 's/^on[[:space:]]*//')
            
            should_execute=1
            check_trigger_condition "$trigger" || should_execute=0
            
            [ "$should_execute" = "1" ] && log "INFO" "--- Trigger: $trigger ---"
            continue
        fi
        
        if [ "$in_trigger_block" = "1" ] && [ "$should_execute" = "1" ]; then
            ! echo "$line" | grep -q '^[[:space:]]' && in_trigger_block=0 && continue
            
            line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            [ -z "$line" ] || echo "$line" | grep -q '^#' && continue
            
            local cmd=$(echo "$line" | awk '{print $1}')
            local args=$(echo "$line" | cut -d' ' -f2-)
            
            case "$cmd" in
                mkdir) exec_mkdir $args ;;
                chmod) exec_chmod $args ;;
                chown) exec_chown $args ;;
                write) exec_write $args ;;
                setprop) exec_setprop $args ;;
                symlink) exec_symlink $args ;;
                copy) exec_copy $args ;;
                rm) exec_rm $args ;;
                rmdir) exec_rmdir $args ;;
                mount) exec_mount $args ;;
                mount_all) exec_mount_all $args ;;
                insmod) exec_insmod $args ;;
                export) exec_export $args ;;
                setrlimit) exec_setrlimit $args ;;
                ifup) exec_ifup $args ;;
                hostname) exec_hostname $args ;;
                wait) exec_wait $args ;;
                trigger) exec_trigger $args ;;
                start) exec_start $args ;;
                stop) exec_stop $args ;;
                restart) exec_restart $args ;;
                class_start) exec_class_start $args ;;
                class_stop) exec_class_stop $args ;;
                class_reset) exec_class_reset $args ;;
                exec) exec_exec $args ;;
                exec_start|execstart) exec_exec_start $args ;;
                *) debug "Unknown: $cmd" ;;
            esac
        fi
    done < "$rc_file"
    
    log "INFO" "=== Finished: $rc_file ==="
    return 0
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================
main() {
    local rc_file="$1"
    
    if [ -z "$rc_file" ]; then
        echo "Usage: $0 <rc_file>"
        echo "Example: $0 init_starter.rc"
        exit 1
    fi
    
    init_properties
    parse_rc_file "$rc_file"
    
    log "INFO" "=== RC Parser Completed Successfully ==="
}

[ "$(basename "$0")" = "rc_parser.sh" ] && main "$@"
