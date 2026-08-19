Цикл діагностики та вирішення проблем з апаратним забезпеченням у Linux (на прикладі бездротового чіпа Broadcom та налаштування віддаленого доступу).

---

### Етап 1: Апаратна ідентифікація та реверс-інжиніринг платформи

**1. Перевірка наявності пристрою на шині PCIe та його ідентифікаторів**

```bash
lspci -nnk | grep -iA3 net

```

* **Навіщо:** Флаг `-nn` виводить апаратні Vendor ID та Device ID (наприклад, `[14e4:43ec]`), а `-k` показує, який модуль ядра (`Kernel driver in use`) зараз прив'язаний до пристрою і які альтернативні модулі є в системі (`Kernel modules`). Це дає зрозуміти, чи бачить ядро фізичний чіп взагалі.

**2. Ідентифікація "порожнього" заліза через CPU та DMI**

```bash
lscpu | grep "Model name"
sudo dmidecode -t bios

```

* **Навіщо:** Якщо виробник не заповнив DMI-таблиці (видає `Default string`), модель процесора та дата релізу BIOS дозволяють точно встановити платформу (Intel Atom x7-Z8750 $\rightarrow$ GPD Win 1 / Pocket 1).

---

### Етап 2: Діагностика ядра та програмних блокувань

**3. Перевірка стану апаратних/програмних блокувань радіомодуля**

```bash
rfkill list

```

* **Навіщо:** Часто інтерфейс відсутній не через драйвер, а через те, що він заблокований на рівні підсистеми rfkill (`Soft blocked: yes` або `Hard blocked: yes`). Якщо стоїть блокування, жодні мережеві демони не побачать адаптер.

**4. Аналіз логів ініціалізації драйвера в кільцевому буфері ядра**

```bash
sudo dmesg | grep -iE "brcm|firmware|nvram"

```

* **Навіщо:** Дозволяє побачити точну причину збою. Для чіпів Broadcom `brcmfmac` у логах з'являється помилка `Direct firmware load for ... failed with error -2` — це прямий доказ того, що ядро не знайшло обов'язкового файлу параметрів NVRAM для конкретної плати.

---

### Етап 3: Дослідження та робота з модулями ядра (Kernel Modules)

**5. Перевірка завантажених модулів та їхніх залежностей**

```bash
lsmod | grep brcm

```

* **Навіщо:** Показує дерево залежностей. Якщо модуль не вивантажується через помилку `Module is in use`, третій стовпчик виводу `lsmod` показує, які саме дочірні модулі (наприклад, `brcmfmac_wcc`, `brcmutil`) блокують батьківський драйвер.

**6. Каскадне вивантаження та завантаження модуля з параметрами**

```bash
sudo rmmod brcmfmac_wcc brcmfmac brcmutil
sudo modprobe brcmfmac firmware_path=/var/home/$USER/firmware/brcm

```

* **Навіщо:** `rmmod` знімає залежні модулі ядра безпосередньо. `modprobe` з прапорцем `firmware_path` примусово змушує драйвер шукати бінарний/текстовий конфіг NVRAM у кастомному каталозі користувача в обхід недоступного на запис `/lib/firmware`.

---

### Етап 4: Автоматизація та персистентність (System Layer)

**7. Фіксація параметрів драйвера на рівні Modprobe**

```bash
echo "options brcmfmac firmware_path=/var/home/$USER/firmware/brcm" | sudo tee /etc/modprobe.d/brcmfmac.conf

```

* **Навіщо:** Конфігураційні файли в `/etc/modprobe.d/` дозволяють передавати аргументи модулям ядра глобально при кожному їх виклику.

**8. Створення раннього Systemd One-Shot юніта**

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

* **Навіщо:** Директива `Before=network-pre.target NetworkManager.service` гарантує, що скидання та повторна ініціалізація адаптера відбудуться *до* того, як мережевий менеджер заблокує інтерфейс або почне опитувати бездротові мережі.

---

### Етап 5: Мережевий стек, фаєрвол та віддалений доступ

**9. Підключення до Wi-Fi виключно через CLI**

```bash
nmcli dev wifi connect "SSID_NAME" password "WIFI_PASSWORD"

```

* **Навіщо:** Команда безпосередньо взаємодіє з NetworkManager через D-Bus API, автоматично створюючи та зберігаючи валідний профіль підключення у `/etc/NetworkManager/system-connections/` без потреби ручного редагування файлів конфігурації.

**10. Увімкнення демона OpenSSH**

```bash
sudo systemctl enable --now sshd

```

* **Навіщо:** Прапорець `--now` виконує дві дії в одній: створює симлінк у `/etc/systemd/system/multi-user.target.wants/` (для автостарту до логіну) та запускає службу в пам'яті прямо зараз.

**11. Персистентне відкриття портів у Firewalld**

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

```

* **Навіщо:** `firewalld` розділяє конфігурацію на runtime та permanent. Флаг `--permanent` зберігає правило в XML-конфігах фаєрволу назавжди, а `--reload` застосовує зміни без обриву існуючих мережевих з'єднань.
