# PublicMacPlug
A (half-assed) bash script designed to circumvent data limits imposed by public WiFi networks. It automatically monitors network traffic, cross-references MAC addresses, and changes the MAC address in the background without requiring the user to manually disconnect, change mac, and reconnect to the WiFi. The user is only prompted to sign in after a MAC address change to maintain connectivity.

## Overview

When using public WiFi networks that impose data limits or restrictions on devices, you often need to change your device’s MAC address to get around those limits. This script was created to automate this process, saving time and effort for long periods of usage on said networks.

### Features

- **Automatic MAC Address Cycling**: Changes MAC address when connectivity issues persist
- **Flexible Configuration**: Customize check intervals, timeout values, and retry attempts
- **Visual Alerts**: Color-coded terminal output for easy status monitoring
- **Audible Alerts**: Beep notifications when manual intervention is needed
- **Robust Error Handling**: Detailed logging and recovery mechanisms
- **Dynamic Interface Detection**: Works with any valid wireless interface

## Requirements

- Linux-based operating system
- Root privileges
- The following dependencies:
  - `ip` ([iproute2](https://archlinux.org/packages/core/x86_64/iw/)) (for network interface management)

  - [`iw`](https://archlinux.org/packages/core/x86_64/iw/) (for wireless interface information)
  - [`macchanger`](https://archlinux.org/packages/extra/x86_64/macchanger/) (for changing MAC addresses)
  - [`curl`](https://archlinux.org/packages/?name=curl) (for connectivity testing)

## Installation

1. Clone this repository or download the script file:

```bash
git clone https://github.com/CousTov/PublicMacPlug.git
cd PublicMacPlug
```

2. Make the script executable:

```bash
chmod +x HalfAssedScript.sh
```

3. Install required dependencies (if not already installed):

   ### For Debian/Ubuntu:

   ```bash
   sudo apt-get update
   sudo apt-get install iproute2 iw macchanger curl
   ```


   ### For Arch Linux:

   ```bash
   sudo pacman -S iproute2 iw macchanger curl
   ```

## Usage

Run the script with root privileges, specifying at least the wireless interface to monitor:

```bash
sudo ./HalfAssedScript.sh -i wlan0
```

Command Line Options

| Option | Long              | Option Description                          | Default                |
| ------ | ----------------- | ------------------------------------------- | ---------------------- |
| -i     | --interface       | Wireless interface to monitor (required)    | None                   |
| -c     | --check-interval  | Main check interval in seconds              | 120                    |
| -t     | --timeout         | Connectivity timeout in seconds             | 15                     |
| -s     | --sanity-interval | Time between sanity checks in seconds       | 15                     |
| -a     | --attempts        | Number of sanity check attempts             | 5                      |
| -m     | --max-fails       | Max connectivity failures before MAC change | 3                      |
| -u     | --url             | URL for connectivity check                  | https://www.google.com |
| -h     | --help            | Show help message                           | N/A                    |

### Examples

Monitor interface wlan0 with default settings:

```bash
sudo ./HalfAssedScript.sh -i wlan0
```

Monitor interface wlan1 with custom settings:

```bash
sudo ./HalfAssedScript.sh -i wlan1 -c 60 -m 5 -u https://example.com
```

## How It Works

**Initialization:** The script validates the specified interface and checks for required dependencies.

**WiFi Check:** The script periodically checks if the interface is connected to a wireless network.

**Connectivity Check:** When WiFi is connected, the script tests internet connectivity.

**Failure Handling:**
 1. If WiFi disconnects, the script waits for reconnection. 
 2. If internet connectivity fails multiple times, the script changes the MAC address.

**Alerts:** Audible alerts notify the user of persistent issues.

## Troubleshooting

**Script fails to start:** Ensure you're running with root privileges

**"Interface not found" error:** Verify the interface name with ip a

**MAC address not changing:** Ensure macchanger is installed and working

**No beep alerts:** It's likely that your terminal config needs to be changed (google is your buddy)

## Customization

The script is designed to be highly customizable. You can modify the default settings at the beginning of the script or use command line arguments for temporary changes.

## License

MIT License
