# GPD Win 1 / Pocket 1 Broadcom Wi-Fi & SSH Setup for Bazzite OS

Automated setup script and diagnostics guide to resolve Wi-Fi driver initialization issues on Broadcom **BCM4356 PCIe** chipsets and enable remote **OpenSSH** access on **Bazzite Linux** (and Fedora Silverblue / Kinoite).

---

## 📌 Target Hardware & Environment

| Component | Identifier / Specification |
|---|---|
| **Target Devices** | GPD Win 1 / GPD Pocket 1 (Intel Atom x7-Z8750) |
| **DMI Identifiers** | `Default string` (AMI BIOS 2017) |
| **Wi-Fi Chipset** | Broadcom Inc. BCM4356 802.11ac Wireless Adapter |
| **PCI ID / Subsystem** | `[14e4:43ec]` / Gemtek `[17f9:0036]` |
| **Kernel Module** | `brcmfmac` |
| **Operating System** | Bazzite OS / Fedora Silverblue |

---

## 🔍 Root Cause Analysis

1. **Missing NVRAM Calibration Data:** The `brcmfmac` kernel driver requires a board-specific NVRAM calibration file (`brcmfmac4356-pcie.txt`) containing antenna gains and regulatory parameters. Without this file, the driver fails to probe the device (`error -2`).
2. **Immutable Filesystem Constraints:** Bazzite utilizes an immutable `/lib/firmware` directory. Firmware files must be placed in a persistent user directory and explicitly passed to the kernel module.
3. **Module Loading Race Conditions:** The kernel loads `brcmfmac` before user configurations take effect, often requiring dependent modules (`brcmfmac_wcc`, `brcmutil`) to be cleanly detached and reinjected before `NetworkManager` initializes.

---

## 🚀 Quick Install (One-Liner)

Run this command directly in your Bazzite terminal:

```bash
curl -fsSL [https://raw.githubusercontent.com/](https://raw.githubusercontent.com/)9840380/gpd-win-bazzite-wifi-fix/main/setup_wifi_ssh.sh | bash
