# migrate-jetson-to-ssd

Once you set up a Jetson Orin Nano or NX to run from an SD card, you may want the option to migrate to an SSD for better performance and storage capacity. While serious developers use an attached PC with SDK Manager and command-line tools to configure their devices and modify them, casual users or those in a pinch might prefer a simpler approach. This toolkit enables you to copy the contents of the SD card to the SSD directly from the Jetson itself, allowing the SSD to serve as the boot medium. In support of the video : https://youtu.be/497u-CcYvE8

**Notes (Updated Jan 30, 2025)** I've only tried this with SD cards and SSDs with the same sector size. There have been a couple reports of people experiencing issues. The common factor seems to be that they are using 32GB SD cards. I will be testing this, but be advised that the NVIDIA recommeneded minimum size for the Orin Nano is a SD card of 64GB.

The scripts assume your SD card is located at /dev/mmcblk0 and your SSD is /dev/nvme0n1. Command line flags allow you to change that (-h for help).
The Jetson Orin Nano has two M.2 Key M slots, one is for a 80mm card (2280), one is for a 30mm card (2230). The other M.2 slot is for a wireless NIC.
I'm using the 2280 slot for the SSD. The 2230 slot is also on /dev/nvme0n1 if you are not using the 2280 slot.

## Features
This is a three step process:
- **Partition Copying**: Copy the partition structure from the SD card to the SSD.
- **Data Cloning**: Clone data from the SD card partitions to the SSD partitions.
- **Boot Configuration**: Modify system files to enable the Jetson Developer Kit to boot from the SSD.

## Requirements
- A NVIDIA Jetson Developer Kit with SSD capabilities. It's only been tested on JetPack 6 machines.
- A running system on an SD card.
- An SSD with a larger capacity than the SD card.
- Unformatted SSDs with no partitions appear to work best
- Root privileges to execute the scripts.
- The SSD cannot be mounted when preparing

## Included Scripts
### 1. `make_partitions.sh`
This script copies the partition structure from the SD card to the SSD.

### 2. `copy_partitions.sh`
This script copies the data from the SD card partitions to the corresponding SSD partitions.

### 3. `configure_ssd_boot.sh`
This script modifies system configuration files on the SSD to enable the Jetson Developer Kit to boot from the SSD. It updates:
- `/boot/extlinux/extlinux.conf` to set the SSD's root partition.
- `/etc/fstab` to match the SSD's UUID for system mounts.

## Usage
### Step 1: CopyMake Partition Structure
Run `make_partitions.sh` to copy the partition structure:
```bash
sudo bash make_partitions.sh
```
### Step 2: Copy Partition Data
Run `copy_partitions.sh` to clone the data:
```bash
sudo  bash copy_partitions.sh 
```
### Step 3: Configure SSD Boot
Run `configure_ssd_boot.sh` to modify the system configuration:
```bash
sudo bash configure_ssd_boot.sh 
```

### Step 4: Resize disk space if SSD > SD 
```bash
# 1. Check current partition layout
sudo parted /dev/nvme0n1 print

# 2. Resize partition 1 to use the entire disk
sudo parted /dev/nvme0n1 resizepart 1 100%

# 3. Resize the filesystem to fill the expanded partition
sudo resize2fs /dev/nvme0n1p1

# 4. Verify the new root filesystem size
df -h /
```

## Notes
- Ensure the SSD has a larger capacity than the SD card.
- Back up your data before running the scripts.
- After completing all steps, reboot the Jetson Developer Kit to verify that it boots from the SSD. (You may have to change the boot order in the UEFI boot sequence).

## Release
### Initial Release
- December, 2024
- Tested on Jetson Orin Nano Super


## License
This project is licensed under the MIT License.
