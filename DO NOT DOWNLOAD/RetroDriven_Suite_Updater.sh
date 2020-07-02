#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Copyright 2019-2020 Alessandro "Locutus73" Miele
# Copyright 2020 RetroDriven

# Version 1.2 - 07/01/2020 - Added MiSTerBIOS Script to Optional Section
# Version 1.1 - 06/15/2020 - Moved Wallpapers to Optional Section; Added Auto Pilot Mode Section ;Added Option to Run All Scripts to Auto Pilot Mode Section
# Version 1.0 - 06/14/2020 - Initial Script Release

# ========= CODE STARTS HERE =========

ALLOW_INSECURE_SSL="true"
DIALOG_HEIGHT="31"

function checkTERMINAL {
#	if [ "$(uname -n)" != "MiSTer" ]
#	then
#		echo "This script must be run"
#		echo "on a MiSTer system."
#		exit 1
#	fi
	if [[ ! (-t 0 && -t 1 && -t 2) ]]
	then
		echo "This script must be run"
		echo "from an interactive terminal."
		echo "Please check your MiSTer.ini and make sure that fb_terminal=1"
		exit 2
	fi
}

function setupINI {
	
	#Wallpapers INI
	if [ ! -f "Update_MiSTerWallpapers.ini" ];then
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerWallpapers/blob/master/Update_MiSTerWallpapers.ini?raw=true" --output "Update_MiSTerWallpapers.ini"
	[ ! -f "Update_MiSTerWallpapers.ini" ] && echo "Error Downloading MiSTerWallpapers INI" && exit 1
	fi

	#MiSTerMAME INI
	if [ ! -f "Update_RetroDriven_MAME_SE.ini" ];then
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerMAME/blob/master/Update_RetroDriven_MAME_SE.ini?raw=true" --output "Update_RetroDriven_MAME_SE.ini"
	[ ! -f "Update_RetroDriven_MAME_SE.ini" ] && echo "Error Downloading RetroDriven_MAME_SE INI" && exit 1
	fi

	#MiSTerBIOS INI
	if [ ! -f "Update_MiSTerBIOS.ini" ];then
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerBIOS/blob/master/Update_MiSTerBIOS.ini?raw=true" --output "Update_MiSTerBIOS.ini"
	[ ! -f "Update_MiSTerBIOS.ini" ] && echo "Error Downloading MiSTerBIOS INI" && exit 1
	fi
}

function setupCURL
{
	[ ! -z "${CURL}" ] && return
	CURL_RETRY="--connect-timeout 15 --max-time 180 --retry 3 --retry-delay 5"
	# test network and https by pinging the most available website 
	SSL_SECURITY_OPTION=""
	curl ${CURL_RETRY} --silent https://github.com > /dev/null 2>&1
	case $? in
		0)
			;;
		60)
			if [[ "${ALLOW_INSECURE_SSL}" == "true" ]]
			then
				SSL_SECURITY_OPTION="--insecure"
			else
				echo "CA certificates need"
				echo "to be fixed for"
				echo "using SSL certificate"
				echo "verification."
				echo "Please fix them i.e."
				echo "using security_fixes.sh"
				exit 2
			fi
			;;
		*)
			echo "No Internet connection"
			exit 1
			;;
	esac
	CURL="curl ${CURL_RETRY} ${SSL_SECURITY_OPTION} --location"
	CURL_SILENT="${CURL} --silent --fail"
}

function installDEBS () {
	DEB_REPOSITORIES=( "${@}" )
	TEMP_PATH="/tmp"
	for DEB_REPOSITORY in "${DEB_REPOSITORIES[@]}"; do
		OLD_IFS="${IFS}"
		IFS="|"
		PARAMS=(${DEB_REPOSITORY})
		DEBS_URL="${PARAMS[0]}"
		DEB_PREFIX="${PARAMS[1]}"
		ARCHIVE_FILES="${PARAMS[2]}"
		STRIP_COMPONENTS="${PARAMS[3]}"
		DEST_DIR="${PARAMS[4]}"
		IFS="${OLD_IFS}"
		if [ ! -f "${DEST_DIR}/$(echo $ARCHIVE_FILES | sed 's/*//g')" ]
		then
			DEB_NAMES=$(${CURL_SILENT} "${DEBS_URL}" | grep -oE "\"${DEB_PREFIX}[a-zA-Z0-9%./_+-]*_(armhf|all)\.deb\"" | sed 's/\"//g')
			MAX_VERSION=""
			MAX_DEB_NAME=""
			for DEB_NAME in $DEB_NAMES; do
				CURRENT_VERSION=$(echo "${DEB_NAME}" | grep -o '_[a-zA-Z0-9%.+-]*_' | sed 's/_//g')
				if [[ "${CURRENT_VERSION}" > "${MAX_VERSION}" ]]
				then
					MAX_VERSION="${CURRENT_VERSION}"
					MAX_DEB_NAME="${DEB_NAME}"
				fi
			done
			[ "${MAX_DEB_NAME}" == "" ] && echo "Error searching for ${DEB_PREFIX} in ${DEBS_URL}" && exit 1
			echo "Downloading ${MAX_DEB_NAME}"
			${CURL} "${DEBS_URL}/${MAX_DEB_NAME}" -o "${TEMP_PATH}/${MAX_DEB_NAME}"
			[ ! -f "${TEMP_PATH}/${MAX_DEB_NAME}" ] && echo "Error: no ${TEMP_PATH}/${MAX_DEB_NAME} found." && exit 1
			echo "Extracting ${ARCHIVE_FILES}"
			ORIGINAL_DIR="$(pwd)"
			cd "${TEMP_PATH}"
			rm data.tar.xz > /dev/null 2>&1
			ar -x "${TEMP_PATH}/${MAX_DEB_NAME}" data.tar.xz
			cd "${ORIGINAL_DIR}"
			rm "${TEMP_PATH}/${MAX_DEB_NAME}"
			mkdir -p "${DEST_DIR}"
			[ ! -f "${TEMP_PATH}/data.tar.xz" ] && echo "Error: no ${TEMP_PATH}/data.tar.xz found." && exit 1
			tar -xJf "${TEMP_PATH}/data.tar.xz" --wildcards --no-anchored --strip-components="${STRIP_COMPONENTS}" -C "${DEST_DIR}" "${ARCHIVE_FILES}"
			rm "${TEMP_PATH}/data.tar.xz" > /dev/null 2>&1
		fi
	done
}

function setupDIALOG {
	if which dialog > /dev/null 2>&1
	then
		DIALOG="dialog"
	else
		if [ ! -f /media/fat/linux/dialog/dialog ]
		then
			setupCURL
			installDEBS "http://http.us.debian.org/debian/pool/main/d/dialog|dialog_1.3-2016|dialog|3|/media/fat/linux/dialog" "http://http.us.debian.org/debian/pool/main/n/ncurses|libncursesw5_6.0|libncursesw.so.5*|3|/media/fat/linux/dialog" "http://http.us.debian.org/debian/pool/main/n/ncurses|libtinfo5_6.0|libtinfo.so.5*|3|/media/fat/linux/dialog"
		fi
		DIALOG="/media/fat/linux/dialog/dialog"
		export LD_LIBRARY_PATH="/media/fat/linux/dialog"
	fi
	
	rm -f "/media/fat/config/dialogrc"
	if [ ! -f "~/.dialogrc" ]
	then
		export DIALOGRC="$(dirname ${ORIGINAL_SCRIPT_PATH})/.dialogrc" > /dev/null 2>&1
		if [ ! -f "${DIALOGRC}" ]
		then
			${DIALOG} --create-rc "${DIALOGRC}"
			sed -i "s/use_colors = OFF/use_colors = ON/g" "${DIALOGRC}"
			sed -i "s/screen_color = (CYAN,BLUE,ON)/screen_color = (CYAN,BLACK,ON)/g" "${DIALOGRC}"
			sync
		fi
	fi
	
	export NCURSES_NO_UTF8_ACS=1
	
	: ${DIALOG_OK=0}
	: ${DIALOG_CANCEL=1}
	: ${DIALOG_HELP=2}
	: ${DIALOG_EXTRA=3}
	: ${DIALOG_ITEM_HELP=4}
	: ${DIALOG_ESC=255}

	: ${SIG_NONE=0}
	: ${SIG_HUP=1}
	: ${SIG_INT=2}
	: ${SIG_QUIT=3}
	: ${SIG_KILL=9}
	: ${SIG_TERM=15}
}

function setupDIALOGtempfile {
	DIALOG_TEMPFILE=`(DIALOG_TEMPFILE) 2>/dev/null` || DIALOG_TEMPFILE=/tmp/dialog_tempfile$$
	trap "rm -f $DIALOG_TEMPFILE" 0 $SIG_NONE $SIG_HUP $SIG_INT $SIG_QUIT $SIG_TERM
}

function readDIALOGtempfile {
	DIALOG_RETVAL=$?
	DIALOG_OUTPUT="$(cat ${DIALOG_TEMPFILE})"
	#rm -f ${DIALOG_TEMPFILE}
	#unset DIALOG_TEMPFILE
}

function MiSTerWallpapers {
	#Check to see if INI file exists
	if [ ! -f "Update_MiSTerWallpapers.ini" ];then

	echo "Downloading MiSTerWallpapers INI"
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerWallpapers/blob/master/Update_MiSTerWallpapers.ini?raw=true" --output "Update_MiSTerWallpapers.ini"
	[ ! -f "Update_MiSTerWallpapers.ini" ] && echo "Error Downloading MiSTerWallpapers INI" && exit 1
	fi

	#Check to see if Wallpapers Script file exists
	if [ ! -f "Update_MiSTerWallpapers.sh" ];then

	echo "Downloading MiSTerWallpapers Script"
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerWallpapers/blob/master/Update_MiSTerWallpapers.sh?raw=true" --output "Update_MiSTerWallpapers.sh"
	[ ! -f "Update_MiSTerWallpapers.sh" ] && echo "Error Downloading MiSTerWallpapers Script" && exit 1
	fi
	
	#Run Wallpapers Script
	./Update_MiSTerWallpapers.sh
	sleep 3
	clear
}

function MiSTerBIOS {
	#Check to see if INI file exists
	if [ ! -f "Update_MiSTerBIOS.ini" ];then

	echo "Downloading MiSTerBIOS INI"
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerBIOS/blob/master/Update_MiSTerBIOS.ini?raw=true" --output "Update_MiSTerBIOS.ini"
	[ ! -f "Update_MiSTerBIOS.ini" ] && echo "Error Downloading MiSTerBIOS INI" && exit 1
	fi

	#Check to see if BIOS Script file exists
	if [ ! -f "Update_MiSTerBIOS.sh" ];then

	echo "Downloading MiSTerBIOS Script"
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerBIOS/blob/master/Update_MiSTerBIOS.sh?raw=true" --output "Update_MiSTerBIOS.sh"
	[ ! -f "Update_MiSTerBIOS.sh" ] && echo "Error Downloading MiSTerBIOS Script" && exit 1
	fi
	
	#Run BIOS Script
	./Update_MiSTerBIOS.sh
	sleep 3
	clear
}

function MiSTerMAME {
	#Check to see if INI file exists
	if [ ! -f "Update_RetroDriven_MAME_SE.ini" ];then

	echo "Downloading MiSTerMAME SE INI"
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerMAME/blob/master/Update_RetroDriven_MAME_SE.ini?raw=true" --output "Update_RetroDriven_MAME_SE.ini"
	[ ! -f "Update_RetroDriven_MAME_SE.ini" ] && echo "Error Downloading RetroDriven_MAME_SE INI" && exit 1
	fi

	#Check to see if Wallpapers Script file exists
	if [ ! -f "Update_RetroDriven_MAME_SE.sh" ];then

	echo "Downloading MiSTerMAME SE Script"
	curl -sL --insecure "https://github.com/RetroDriven/MiSTerMAME/blob/master/Update_RetroDriven_MAME_SE.sh?raw=true" --output "Update_RetroDriven_MAME_SE.sh"
	[ ! -f "Update_RetroDriven_MAME_SE.sh" ] && echo "Error Downloading MiSTerMAME SE Script" && exit 1
	fi
	
	#Run MiSTerMAME SE Script
	./Update_RetroDriven_MAME_SE.sh
	sleep 3
	clear
}

function Update_Official {
	#Check to see if Official Update Script file exists
	if [ ! -f "update.sh" ];then

	echo "Downloading Official MiSTer Update Script"
	curl -sL --insecure "https://github.com/MiSTer-devel/Updater_script_MiSTer/blob/master/update.sh?raw=true" --output "update.sh"
	[ ! -f "update.sh" ] && echo "Error Downloading Official MiSTer Update Script" && exit 1
	fi
	
	#Run Official MiSTer Update Script

	echo
    echo "=========================================================================="
    echo "                     Running Official MiSTer Updater                      "
    echo "=========================================================================="
    echo
	sleep 1

	./update.sh
	sleep 3
	clear
}

function Update_LLAPI {
	#Check to see if LLAPI Update Script file exists
	if [ ! -f "update_llapi.sh" ];then

	echo "Downloading MiSTer LLAPI Update Script"
	curl -sL --insecure "https://github.com/MiSTer-LLAPI/Updater_script_MiSTer/blob/master/update_llapi.sh?raw=true" --output "update_llapi.sh"
	[ ! -f "update_llapi.sh" ] && echo "Error Downloading MiSTer LLAPI Update Script" && exit 1
	fi
	
	#Run MiSTer LLAPI Update Script

	echo
    echo "=========================================================================="
    echo "                       Running MiSTer LLAPI Updater                       "
    echo "=========================================================================="
    echo
	sleep 1

	./update_llapi.sh
	sleep 3
	clear
}

function Update_All {

	#Run All Scripts
	MiSTerMAME
	MiSTerWallpapers
	MiSTerBIOS
	Update_LLAPI
	Update_Official
}

function Update_All_Essential {

	MiSTerMAME
	Update_Official
}

function Update_All_Optional {

	MiSTerWallpapers
	MiSTerBIOS
	Update_LLAPI
	
}

#Menu Options
DIALOG_TITLE="RetroDriven MiSTer Update Suite v1.2"
function showPleaseWAIT {
	${DIALOG} --title "${DIALOG_TITLE}" \
	--infobox "Please wait..." 0 0
}

function showMainMENU {
	setupDIALOGtempfile
	${DIALOG} --clear --no-tags --item-help --ok-label "Select" \
		--title "${DIALOG_TITLE}" \
		--menu "Please Adjust your INI Files as needed before running these Scripts." ${DIALOG_HEIGHT} 0 999 \
		"" "===== Essential Scripts =====" "" \
		"updateAllEssential" "RUN ALL Essential Scripts (Auto Pilot Mode)" "" \
		"updateMM" "RetroDriven MiSTerMAME SE Updater" "" \
		"updateOfficial" "Official MiSTer Updater" "" \
		"" "===== Optional Scripts =====" "" \
		"updateAllOptional" "RUN ALL Optional Scripts (Auto Pilot Mode)" "" \
		"updateMW" "RetroDriven MiSTerWallpapers Updater" "" \
		"updateMB" "RetroDriven MiSTerBIOS Updater" "" \
		"updateLLAPI" "MiSTer LLAPI Updater" "" \
		"" "===== Auto Pilot Mode =====" "" \
		"updateAll" "Run Essential + Optional Scripts (Auto Pilot All Scripts)" "" \
		2> ${DIALOG_TEMPFILE}
	readDIALOGtempfile
}

clear
#checkTERMINAL
setupINI
setupDIALOG

while true; do
	showMainMENU
	case ${DIALOG_RETVAL} in
		${DIALOG_OK})
			case "${DIALOG_OUTPUT}" in
				updateMM)
					clear
					MiSTerMAME
					;;
				updateMW)
					clear
					MiSTerWallpapers
					;;
				updateMB)
					clear
					MiSTerBIOS
					;;
				updateAll)
					clear
					Update_All
					;;
				updateAllEssential)
					clear
					Update_All_Essential
					;;
				updateAllOptional)
					clear
					Update_All_Optional
					;;
				updateOfficial)
					clear
					Update_Official
					;;
				updateLLAPI)
					clear
					Update_LLAPI
					;;
			esac
			;;
		*)
			break;;
	esac
done

clear

exit 0
