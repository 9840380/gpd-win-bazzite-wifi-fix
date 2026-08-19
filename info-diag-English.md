### Phase 1: Hardware Identification & Platform Reverse Engineering

**1. Querying the PCIe Bus and Device Identifiers**

```bash
lspci -nnk | grep -iA3 net

```

* **Why:** The `-nn` flag displays both vendor/device names and raw hexadecimal IDs (e.g., `[14e4:43ec]`), while `-k` reveals the active kernel driver (`Kernel driver in use: brcmfmac`) and alternative available modules. This proves whether the physical silicon is detected on the bus regardless of high-level OS support.

**2. Fingerprinting Obscure Hardware via CPU and DMI**

```bash
lscpu | grep "Model name"
sudo dmidecode -t bios

```

* **Why:** When OEM firmware contains unpopulated DMI strings (`Default string`), cross-referencing the microarchitecture (Intel Atom x7-Z8750) and BIOS release timestamp identifies the exact hardware generation (GPD Win 1 / Pocket 1).

---

### Phase 2: Kernel Diagnostics & Radio Subsystem Triage

**3. Auditing Hardware and Software RF Kill Switches**

```bash
rfkill list

```

* **Why:** Verifies whether the wireless transmission subsystem is disabled at the software or hardware layer (`Soft blocked: yes` / `Hard blocked: yes`). If blocked, upper network layers (NetworkManager, wpa_supplicant) will ignore the interface entirely.

**4. Inspecting Kernel Ring Buffer for Initialization Failures**

```bash
sudo dmesg | grep -iE "brcm|firmware|nvram"

```

* **Why:** Pinpoints the exact initialization failure. Broadcom `brcmfmac` drivers routinely fail with `Direct firmware load for ... failed with error -2` when missing board-specific NVRAM calibration tables.

---

### Phase 3: Kernel Module Manipulation & Parameter Overrides

**5. Inspecting Loaded Modules and Dependency Chains**

```bash
lsmod | grep brcm

```

* **Why:** Displays active kernel modules and their dependency reference counts. Identifies sub-modules (such as `brcmfmac_wcc` or `brcmutil`) holding open handles when a module refuses to unload (`Module is in use`).

**6. Cascaded Module Unloading and Manual Parameter Injection**

```bash
sudo rmmod brcmfmac_wcc brcmfmac brcmutil
sudo modprobe brcmfmac firmware_path=/var/home/$USER/firmware/brcm

```

* **Why:** `rmmod` systematically removes the dependent module hierarchy. `modprobe` with `firmware_path` forces the driver to read NVRAM files from a writable user directory, bypassing immutable, read-only system paths like `/lib/firmware`.

---

### Phase 4: System Layer Automation & Persistence

**7. Persisting Kernel Driver Options**

```bash
echo "options brcmfmac firmware_path=/var/home/$USER/firmware/brcm" | sudo tee /etc/modprobe.d/brcmfmac.conf

```

* **Why:** Files in `/etc/modprobe.d/` enforce module arguments globally whenever the kernel triggers a module load via udev or manual calls.

**8. Constructing an Early-Stage Systemd One-Shot Unit**

```bash
sudo tee /etc/systemd/system/broadcom-wifi-fix.service << 'EOF'
[Unit]
Description=Broadcom Wi-Fi NVRAM Fix
Before=network-pre.target NetworkManager.service
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'rfkill unblock wifi 2>/dev/null || true; modprobe -r brcmfmac_wcc brcmfmac brcmutil 2>/dev/null || true; modprobe brcmfmac firmware_path=/var/home/bazzite/firmware/brcm'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

```

* **Why:** The `Before=network-pre.target NetworkManager.service` directive ensures hardware unblocking and module reinjection occur before network daemons attempt interface discovery.

---

### Phase 5: Network Stack, Firewall & Remote Access

**9. Programmatic Wi-Fi Association via NetworkManager CLI**

```bash
nmcli dev wifi connect "SSID_NAME" password "WIFI_PASSWORD"

```

* **Why:** Interacts directly with NetworkManager via D-Bus, dynamically creating and encrypting connection profiles in `/etc/NetworkManager/system-connections/` without requiring manual file syntax editing.

**10. Enabling OpenSSH Daemon**

```bash
sudo systemctl enable --now sshd

```

* **Why:** The `--now` flag combines profile symlinking for persistent startup during `multi-user.target` initialization (prior to user login) and starts the runtime process immediately.

**11. Persistent Firewall Service Allowance**

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

```

* **Why:** Firewalld maintains separate runtime and permanent configuration tables. `--permanent` writes the XML rules to disk across reboots, while `--reload` applies them instantly without dropping active sessions.
