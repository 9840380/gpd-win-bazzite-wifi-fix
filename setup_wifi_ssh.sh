cat << 'EOF' > ~/setup_wifi_ssh.sh
#!/usr/bin/env bash
# ==============================================================================
# Target Device : GPD Win 1 / GPD Pocket 1 (Intel Atom x7-Z8750)
# Network Card  : Broadcom BCM4356 802.11ac PCIe [14e4:43ec]
# Subsystem     : Gemtek Technology Co., Ltd [17f9:0036]
# Kernel Driver : brcmfmac
# OS            : Bazzite Linux / Fedora Silverblue
# Description   : Broadcom NVRAM injection, Wi-Fi auto-reload & OpenSSH server setup
# ==============================================================================


# Exit immediately if a command exits with a non-zero status
set -e

# ==============================================================================
# 1. CREATE FIRMWARE DIRECTORY AND WRITE BROADCOM NVRAM CONFIGURATION
# ==============================================================================
# Broadcom BCM4356 PCIe adapters require an NVRAM (.txt) calibration file.
# We create a persistent directory in the user's home folder and write the
# specific hardware tuning parameters (gains, power limits, regulatory data).

echo "[1/5] Creating firmware directory and NVRAM file..."
mkdir -p "$HOME/firmware/brcm"

cat << 'FILE_EOF' > "$HOME/firmware/brcm/brcmfmac4356-pcie.txt"
# Sample variables file for BCM94356Z NGFF 22x30mm iPA, iLNA board with PCIe for production package
NVRAMRev=$Rev: 373428 $
sromrev=11
boardrev=0x1101
boardtype=0x073e
boardflags=0x02400201
boardflags2=0x00802000
boardflags3=0x0000000a
macaddr=00:90:4c:1a:10:01
ccode=X2
regrev=1
antswitch=0
pdgain5g=4
pdgain2g=4
tworangetssi2g=0
tworangetssi5g=0
paprdis=0
femctrl=10
vendid=0x14e4
devid=0x43a3
manfid=0x2d0
nocrc=1
otpimagesize=502
xtalfreq=37400
rxgains2gelnagaina0=0
rxgains2gtrisoa0=7
rxgains2gtrelnabypa0=0
rxgains5gelnagaina0=0
rxgains5gtrisoa0=11
rxgains5gtrelnabypa0=0
rxgains5gmelnagaina0=0
rxgains5gmtrisoa0=13
rxgains5gmtrelnabypa0=0
rxgains5ghelnagaina0=0
rxgains5ghtrisoa0=12
rxgains5ghtrelnabypa0=0
rxgains2gelnagaina1=0
rxgains2gtrisoa1=7
rxgains2gtrelnabypa1=0
rxgains5gelnagaina1=0
rxgains5gtrisoa1=10
rxgains5gtrelnabypa1=0
rxgains5gmelnagaina1=0
rxgains5gmtrisoa1=11
rxgains5gmtrelnabypa1=0
rxgains5ghelnagaina1=0
rxgains5ghtrisoa1=11
rxgains5ghtrelnabypa1=0
rxchain=3
txchain=3
aa2g=3
aa5g=3
agbg0=2
agbg1=2
aga0=2
aga1=2
tssipos2g=1
extpagain2g=2
tssipos5g=1
extpagain5g=2
tempthresh=255
tempoffset=255
rawtempsense=0x1ff
pa2ga0=-147,6192,-705
pa2ga1=-161,6041,-701
pa5ga0=-194,6069,-739,-188,6137,-743,-185,5931,-725,-171,5898,-715
pa5ga1=-190,6248,-757,-190,6275,-759,-190,6225,-757,-184,6131,-746
subband5gver=0x4
pdoffsetcckma0=0x4
pdoffsetcckma1=0x4
pdoffset40ma0=0x0000
pdoffset80ma0=0x0000
pdoffset40ma1=0x0000
pdoffset80ma1=0x0000
maxp2ga0=80
maxp5ga0=78,78,78,78
maxp2ga1=80
maxp5ga1=78,78,78,78
cckbw202gpo=0x0000
cckbw20ul2gpo=0x0000
mcsbw202gpo=0x99644422
mcsbw402gpo=0x99644422
dot11agofdmhrbw202gpo=0x6666
ofdmlrbw202gpo=0x0022
mcsbw205glpo=0x88766663
mcsbw405glpo=0x88666663
mcsbw805glpo=0xbb666665
mcsbw205gmpo=0xd8666663
mcsbw405gmpo=0x88666663
mcsbw805gmpo=0xcc666665
mcsbw205ghpo=0xdc666663
mcsbw405ghpo=0xaa666663
mcsbw805ghpo=0xdd666665
mcslr5glpo=0x0000
mcslr5gmpo=0x0000
mcslr5ghpo=0x0000
sb20in40hrpo=0x0
sb20in80and160hr5glpo=0x0
sb40and80hr5glpo=0x0
sb20in80and160hr5gmpo=0x0
sb40and80hr5gmpo=0x0
sb20in80and160hr5ghpo=0x0
sb40and80hr5ghpo=0x0
sb20in40lrpo=0x0
sb20in80and160lr5glpo=0x0
sb40and80lr5glpo=0x0
sb20in80and160lr5gmpo=0x0
sb40and80lr5gmpo=0x0
sb20in80and160lr5ghpo=0x0
sb40and80lr5ghpo=0x0
dot11agduphrpo=0x0
dot11agduplrpo=0x0
phycal_tempdelta=255
temps_period=15
temps_hysteresis=15
rssicorrnorm_c0=4,4
rssicorrnorm_c1=4,4
rssicorrnorm5g_c0=1,2,3,1,2,3,6,6,8,6,6,8
rssicorrnorm5g_c1=1,2,3,2,2,2,7,7,8,7,7,8
FILE_EOF

# Define absolute path (/var/home/<user> on Bazzite/Silverblue)
USER_DIR="/var/home/$USER/firmware/brcm"

# ==============================================================================
# 2. CONFIGURE MODPROBE DEFAULT PARAMETERS
# ==============================================================================
# Tells the Linux kernel where to look for the NVRAM config file every time
# the brcmfmac module is loaded.
echo "[2/5] Configuring modprobe options..."
echo "options brcmfmac firmware_path=$USER_DIR" | sudo tee /etc/modprobe.d/brcmfmac.conf > /dev/null

# ==============================================================================
# 3. CREATE SYSTEMD SERVICE FOR HARDWARE INITIALIZATION
# ==============================================================================
# On boot, the kernel often initializes brcmfmac before user-space NVRAM is
# parsed or keeps default interfaces blocked.
# This unit runs BEFORE NetworkManager:
# 1. Unblocks software RF switches (rfkill).
# 2. Removes in-use modules (brcmfmac_wcc, brcmfmac, brcmutil).
# 3. Reloads brcmfmac pointing directly to the firmware directory.
echo "[3/5] Creating systemd service for Wi-Fi module reload..."
sudo tee /etc/systemd/system/broadcom-wifi-fix.service > /dev/null << SERVICE_EOF
[Unit]
Description=Broadcom Wi-Fi NVRAM Fix
Before=network-pre.target NetworkManager.service
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'rfkill unblock wifi 2>/dev/null || true; modprobe -r brcmfmac_wcc brcmfmac brcmutil 2>/dev/null || true; modprobe brcmfmac firmware_path=$USER_DIR'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# ==============================================================================
# 4. ENABLE SYSTEM SERVICES (SSH & WI-FI FIX)
# ==============================================================================
echo "[4/5] Enabling services..."
# Reload systemd manager configuration to recognize new service files
sudo systemctl daemon-reload

# Enable our Wi-Fi fix service at multi-user boot target
sudo systemctl enable broadcom-wifi-fix.service

# Enable and immediately start OpenSSH server (sshd)
sudo systemctl enable --now sshd

# ==============================================================================
# 5. CONFIGURE FIREWALL RULES FOR SSH (PORT 22)
# ==============================================================================
echo "[5/5] Configuring firewall..."
# Open TCP port 22 permanently in firewalld (default firewall on Bazzite)
sudo firewall-cmd --permanent --add-service=ssh

# Reload firewall rules to apply the change immediately without restarting
sudo firewall-cmd --reload

echo "--------------------------------------------------------"
echo "Setup finished! To connect to Wi-Fi from CLI run:"
echo "  nmcli dev wifi connect 'YOUR_SSID' password 'YOUR_PASS'"
echo "--------------------------------------------------------"
EOF

chmod +x ~/setup_wifi_ssh.sh
./setup_wifi_ssh.sh
