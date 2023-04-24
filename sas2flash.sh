#!/bin/bash

#user variables
card="0"
flash="nobios"
flashcard="Yes"

location="/mnt/user/isos/Other"
#Functions
check_hba_firmware() {
  # Run sas2flash -list and capture the output
  sas2flash_output=$(${location}/sas2flash -list)

  # Print the sas2flash -list output
  echo "sas2flash -list output:"
  echo "$sas2flash_output"
  echo

  # Extract the firmware version and product ID from the output
  firmware_version=$(echo "$sas2flash_output" | grep "Firmware Version" | awk '{print $3}')
  product_id=$(echo "$sas2flash_output" | grep "Firmware Product ID" | awk '{print $5}')
  card_number=$(echo "$sas2flash_output" | grep -m1 "Controller #" | awk '{print $3}')

  # Check if the product ID indicates IT mode
  if [ "$product_id" == "0x0073" ] || [ "$product_id" == "0x0074" ]; then
    echo "IT mode firmware detected: $firmware_version"
    echo "Your operating system (such as Unraid, TrueNAS, ZFS, etc.) should have direct disk access"
  else
    needs_flashing=true
    echo "Non-IT mode firmware detected: $firmware_version"
    echo "Your operating system (such as Unraid, TrueNAS, ZFS, etc.) requires direct disk access"
    echo "You may need to flash with LSI P20 firmware in IT mode"
    echo "Please verify firmware compatibility before flashing"
  fi

  # Print the card number and instructions to assign it to the card variable
  echo
  echo "Card number: $card_number"
  echo "To flash the card, assign the card number $card_number to the 'card' variable in the script."
}


check_array_status() {
  array_status=$(sudo /usr/local/sbin/mdcmd status | awk -F= '/mdState/ {print $2}')

  if [[ "$array_status" == "STARTED" ]]; then
    echo "Array is started. You must stop the array to continue."
    exit 1
  elif [[ "$array_status" == "STOPPED" ]]; then
    echo "Array is stopped. Continuing with the script."
  else
    echo "Unknown array status. Exiting."
    exit 1
  fi
}

function download_firmware() {
  local FIRMWARE_URL='https://docs.broadcom.com/docs-and-downloads/host-bus-adapters/host-bus-adapters-common-files/sas_sata_6g_p20/9211-8i_Package_P20_IR_IT_FW_BIOS_for_MSDOS_Windows.zip'
  local FIRMWARE_FILE='firmware.zip'
  local FIRMWARE_DIR='$location/9211-8i_firmware'

  # create the firmware directory if it doesn't exist
  mkdir -p $FIRMWARE_DIR

  # download the firmware zip file
  curl -L $FIRMWARE_URL -o $FIRMWARE_FILE

  # extract the firmware files to the firmware directory
  unzip -j -d $FIRMWARE_DIR $FIRMWARE_FILE 9211-8i_Package_P20_IR_IT_FW_BIOS_for_MSDOS_Windows/Firmware/HBA_9211_8i_IT/2118it.bin 9211-8i_Package_P20_IR_IT_FW_BIOS_for_MSDOS_Windows/sasbios_rel/mptsas2.rom

  # clean up the firmware zip file
  rm $FIRMWARE_FILE
}

function flash_firmware() {
  check_array_status
  local card_number="${1:-0}"
  local flash_option="${2:-nobios}"
  local FIRMWARE_DIR='$location/9211-8i_firmware'
  local FIRMWARE_FILE='2118it.bin'
  local BIOS_FILE='mptsas2.rom'

  if [ "$flash_option" == "bios" ]; then
    echo "Flashing firmware and BIOS on card $card_number..."
    $location/sas2flash -o -f "${FIRMWARE_DIR}/${FIRMWARE_FILE}" -b "${FIRMWARE_DIR}/${BIOS_FILE}" -c "$card_number"
  elif [ "$flash_option" == "nobios" ]; then
    echo "Flashing firmware on card $card_number without BIOS..."
    $location/sas2flash -o -f "${FIRMWARE_DIR}/${FIRMWARE_FILE}" -c "$card_number"
  else
    echo "Invalid flash option specified. Please use 'bios' or 'nobios'."
    return 1
  fi
}


#run
check_hba_firmware
download_firmware
check_array_status
echo "end"