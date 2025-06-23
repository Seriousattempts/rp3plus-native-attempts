#!/bin/sh

log() {
	logger -p daemon.info -t firmware "$@"
}

load_error() {
	log "Failed to load $FIRMWARE for $DEVPATH"
	echo "-1" > "/sys$DEVPATH/loading"
}

load_file() {
	local firmware_file="/lib/firmware/postmarketos/sprd/$1"
	
	log "Loading firmware file $firmware_file"
	
	if [ ! -f "$firmware_file" ]; then
		load_error
	else
		echo 1 > "/sys$DEVPATH/loading"
		cat "$firmware_file" > "/sys$DEVPATH/data"
		echo 0 > "/sys$DEVPATH/loading"
		log "Loading firmware complete"
	fi
}

log "Attempting to load firmware $FIRMWARE for $DEVPATH"

if [ -e "/sys$DEVPATH/loading" ]; then
	case "$FIRMWARE" in
		# WiFi/BT firmware
		sprd/wcnmodem.bin)
			load_file wcnmodem.bin
			;;
		# GNSS firmware
		sprd/gnssmodem.bin)
			load_file gnssmodem.bin
			;;
		# LTE Modem
		sprd/l_modem.bin)
			load_file l_modem.bin
			;;
		# Delta NV
		sprd/l_deltanv.bin)
			load_file l_deltanv.bin
			;;
		# Fix NV
		sprd/l_fixnv.bin)
			load_file l_fixnv.bin
			;;
		# Data Modem DSP
		sprd/l_gdsp.bin)
			load_file l_gdsp.bin
			;;
		# LTE DSP
		sprd/l_ldsp.bin)
			load_file l_ldsp.bin
			;;
		# Audio/GPS DSP (previously failing)
		sprd/l_agdsp.bin)
			load_file l_agdsp.bin
			;;
		# CDMA DSP (previously failing)
		sprd/l_cdsp.bin)
			load_file l_cdsp.bin
			;;
		# CM4 firmware (previously failing)
		sprd/pm_sys.bin)
			load_file pm_sys.bin
			;;
		*)
			load_error
			;;
	esac
fi

