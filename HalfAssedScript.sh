#!/bin/bash

# PublicMacPlug
# Purpose: To get around the data limit imposed by public wifis by spoofing mac address

# Default Config
INTERFACE=""
CHECK_INTERVAL=120                        # Main check interval in seconds
CONNECTIVITY_TIMEOUT=15                   # Time to wait for connectivity check in seconds
SANITY_CHECK_INTERVAL=15                  # Time between sanity checks in seconds
SANITY_CHECK_ATTEMPTS=5                   # Number of sanity check attempts
BEEP_INTERVAL=1                           # Time between beeps in seconds
MAX_CONNECTIVITY_FAILS=3                  # Number of connectivity failures before MAC change
CONNECTIVITY_URL="https://www.google.com" # URL to check connectivity

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# print help message function
show_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -i, --interface INTERFACE  Specify wireless interface (required)"
  echo "  -c, --check-interval SEC   Set main check interval in seconds (default: 120)"
  echo "  -t, --timeout SEC          Set connectivity timeout in seconds (default: 15)"
  echo "  -s, --sanity-interval SEC  Set sanity check interval in seconds (default: 15)"
  echo "  -a, --attempts NUM         Set sanity check attempts (default: 5)"
  echo "  -m, --max-fails NUM        Set max connectivity failures before MAC change (default: 3)"
  echo "  -u, --url URL              Set URL for connectivity check (default: https://www.google.com)"
  echo "  -h, --help                 Show this help message"
  exit 0
}

# args
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -i | --interface)
      INTERFACE="$2"
      shift 2
      ;;
    -c | --check-interval)
      CHECK_INTERVAL="$2"
      shift 2
      ;;
    -t | --timeout)
      CONNECTIVITY_TIMEOUT="$2"
      shift 2
      ;;
    -s | --sanity-interval)
      SANITY_CHECK_INTERVAL="$2"
      shift 2
      ;;
    -a | --attempts)
      SANITY_CHECK_ATTEMPTS="$2"
      shift 2
      ;;
    -m | --max-fails)
      MAX_CONNECTIVITY_FAILS="$2"
      shift 2
      ;;
    -u | --url)
      CONNECTIVITY_URL="$2"
      shift 2
      ;;
    -h | --help)
      show_help
      ;;
    *)
      log_message "ERROR" "Unknown option: $1"
      show_help
      ;;
    esac
  done

  # check required param
  if [[ -z "$INTERFACE" ]]; then
    log_message "ERROR" "Wireless interface must be specified with -i or --interface"
    show_help
  fi

  # verify
  if ! ip link show "$INTERFACE" &>/dev/null; then
    log_message "ERROR" "Interface $INTERFACE does not exist"
    exit 1
  fi

  # verify 2
  if ! iw dev "$INTERFACE" info &>/dev/null; then
    log_message "ERROR" "$INTERFACE is not a wireless interface"
    exit 1
  fi
}

# timestamped messages function
log_message() {
  local level=$1
  local message=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  case $level in
  "INFO")
    echo -e "${BLUE}[${timestamp}] ℹ️ ${NC}${message}"
    ;;
  "SUCCESS")
    echo -e "${GREEN}[${timestamp}] ✅ ${NC}${message}"
    ;;
  "WARNING")
    echo -e "${YELLOW}[${timestamp}] ⚠️ ${NC}${message}"
    ;;
  "ERROR")
    echo -e "${RED}[${timestamp}] ❌ ${NC}${message}"
    ;;
  esac
}

# beep beep
beep_continuously() {
  log_message "WARNING" "Starting continuous beep alert..."
  while true; do
    echo -e "\a"
    sleep $BEEP_INTERVAL
  done
}

# check WiFi connection function
check_wifi() {
  log_message "INFO" "Checking WiFi connection..."
  if iw dev "$INTERFACE" link 2>/dev/null | grep -q "SSID"; then
    log_message "SUCCESS" "WiFi is connected"
    return 0
  fi
  log_message "ERROR" "WiFi is not connected"
  return 1
}

# check internet connectivity function
check_connectivity() {
  log_message "INFO" "Checking internet connectivity..."
  if curl -Is "$CONNECTIVITY_URL" --connect-timeout "$CONNECTIVITY_TIMEOUT" -o /dev/null 2>&1; then
    log_message "SUCCESS" "Internet connectivity confirmed"
    return 0
  fi
  log_message "ERROR" "No internet connectivity"
  return 1
}

# change MAC address function
change_mac() {
  log_message "INFO" "Initiating MAC address change..."
  local old_mac=$(ip link show "$INTERFACE" | grep -o 'link/ether [0-9a-f:]\+' | awk '{print $2}')

  # interface down
  ip link set "$INTERFACE" down

  # Change MAC
  if ! macchanger -r "$INTERFACE" &>/dev/null; then
    log_message "ERROR" "Failed to change MAC address"
    # interface back up (even if MAC change failed as not to perma down)
    ip link set "$INTERFACE" up
    return 1
  fi

  # interface back up main
  ip link set "$INTERFACE" up

  local new_mac=$(ip link show "$INTERFACE" | grep -o 'link/ether [0-9a-f:]\+' | awk '{print $2}')
  log_message "SUCCESS" "MAC address changed from ${old_mac} to ${new_mac}"
  return 0
}

# sanity check
run_sanity_check() {
  local check_type=$1
  local check_function=$2
  local check_name=$3

  log_message "INFO" "Performing $check_name sanity check..."
  local attempts=0

  while [ $attempts -lt $SANITY_CHECK_ATTEMPTS ]; do
    ((attempts++))
    log_message "INFO" "$check_name sanity check attempt ${attempts}/${SANITY_CHECK_ATTEMPTS}"

    if $check_function; then
      log_message "SUCCESS" "$check_name sanity check passed"
      return 0
    fi

    if [ $attempts -lt $SANITY_CHECK_ATTEMPTS ]; then
      log_message "INFO" "Waiting ${SANITY_CHECK_INTERVAL} seconds before next attempt..."
      sleep $SANITY_CHECK_INTERVAL
    fi
  done

  log_message "ERROR" "$check_name sanity check failed after ${SANITY_CHECK_ATTEMPTS} attempts"
  return 1
}

# WiFi sanity check function
wifi_sanity_check() {
  run_sanity_check "wifi" check_wifi "WiFi"
}

# connectivity sanity check function
connectivity_sanity_check() {
  run_sanity_check "connectivity" check_connectivity "Connectivity"
}

# full sanity check function
full_sanity_check() {
  log_message "INFO" "Performing full sanity check..."
  if ! wifi_sanity_check; then
    return 1
  fi

  if ! connectivity_sanity_check; then
    return 1
  fi
  log_message "SUCCESS" "Full sanity check passed"
  return 0
}

# main loop
main() {
  local beep_pid=""
  local connectivity_fails=0

  log_message "INFO" "Starting network monitoring service..."
  log_message "INFO" "Monitoring interface: $INTERFACE"
  log_message "INFO" "Main check interval: ${CHECK_INTERVAL} seconds"
  log_message "INFO" "Max connectivity failures before MAC change: ${MAX_CONNECTIVITY_FAILS}"

  while true; do
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    log_message "INFO" "Starting new check cycle"

    if ! check_wifi; then
      connectivity_fails=0

      # Get attention via beep func for manual intervention is no wifi after sanity check
      if ! wifi_sanity_check; then
        beep_continuously &
        beep_pid=$!

        log_message "WARNING" "Waiting for WiFi connection to be restored..."
        while ! check_wifi; do
          sleep 3
        done

        # Stop beeping when WiFi is restored
        if [ -n "$beep_pid" ]; then
          kill $beep_pid 2>/dev/null
          beep_pid=""
        fi
      fi
    else
      if ! check_connectivity; then
        ((connectivity_fails++))
        log_message "WARNING" "Connectivity check failed (Attempt ${connectivity_fails}/${MAX_CONNECTIVITY_FAILS})"

        if [ $connectivity_fails -ge $MAX_CONNECTIVITY_FAILS ]; then
          # change mac if failed too many times
          log_message "INFO" "Multiple connectivity failures detected, attempting MAC change..."
          change_mac
          connectivity_fails=0

          # full sanity check after MAC change
          if ! full_sanity_check; then
            # beep to alert user for manual intervention if full sanity check fails
            beep_continuously &
            beep_pid=$!

            log_message "WARNING" "Waiting for internet connectivity to be restored..."
            while ! check_connectivity; do
              sleep 3
            done

            # stop beep when connectivity is back
            if [ -n "$beep_pid" ]; then
              kill $beep_pid 2>/dev/null
              beep_pid=""
            fi
          fi
        else
          # wait before next attempt if current fail < max fail
          log_message "INFO" "Waiting ${SANITY_CHECK_INTERVAL} seconds before next attempt..."
          sleep $SANITY_CHECK_INTERVAL
        fi
      else
        # all is well
        connectivity_fails=0
        log_message "SUCCESS" "All systems operational"
        log_message "INFO" "Sleeping for ${CHECK_INTERVAL} seconds..."
        sleep $CHECK_INTERVAL
      fi
    fi
  done
}

# Cleanup function
cleanup() {
  log_message "WARNING" "Script termination requested"
  pkill -P $$ &>/dev/null
  log_message "INFO" "Cleanup completed"
  exit 0
}

# Check required dependencies
check_dependencies() {
  local missing_deps=()

  for cmd in ip iw macchanger curl; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_deps+=("$cmd")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    log_message "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    log_message "INFO" "Please install the missing dependencies and try again"
    exit 1
  fi
}

# Check for root privileges
check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_message "ERROR" "This script requires root privileges"
    log_message "INFO" "Please run with sudo or as root"
    exit 1
  fi
}

# Trap
trap cleanup INT TERM

# Main
check_root
check_dependencies
parse_args "$@"
main
