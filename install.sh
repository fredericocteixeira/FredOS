#!/bin/bash

set -e

echo "▄████  █▄▄▄▄ ▄███▄   ██▄       ████▄    ▄▄▄▄▄   
█▀   ▀ █  ▄▀ █▀   ▀  █  █      █   █   █     ▀▄ 
█▀▀    █▀▀▌  ██▄▄    █   █     █   █ ▄  ▀▀▀▀▄   
█      █  █  █▄   ▄▀ █  █      ▀████  ▀▄▄▄▄▀    
 █       █   ▀███▀   ███▀                     "

lsblk
read -p "Disk to install to (e.g., /dev/sda): " DISK

read -p "Hostname: " HOSTNAME

read -p "Username: " USERNAME

while true; do
  read -s -p "Password for $USERNAME: " PASSWORD
  echo
  read -s -p "Confirm password: " PASSWORD_CONFIRM
  echo
  [ "$PASSWORD" = "$PASSWORD_CONFIRM" ] && break || echo "Passwords do not match, try again."
done

echo "Partitioning $DISK..."

fdisk "$DISK" <<EOF
g
n
1

+512M
t
1
1
n
2


w
EOF

mkfs.fat -F32 "${DISK}1"

mkfs.ext4 "${DISK}2"

mount "${DISK}2" /mnt

mkdir /mnt/boot

mount "${DISK}1" /mnt/boot

pacstrap /mnt base linux linux-firmware grub efibootmgr networkmanager sudo nvim nano river foot

genfstab -U /mnt >> /mnt/etc/fstab

read -p "Region (e.g., Europe, America): " TZ_REGION

read -p "City (e.g., Paris, New_York): " TZ_CITY

TIMEZONE="$TZ_REGION/$TZ_CITY"

if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
  echo "Invalid timezone: /usr/share/zoneinfo/$TIMEZONE"
  exit 1
fi

arch-chroot /mnt /bin/bash <<EOF

echo "$HOSTNAME" > /etc/hostname

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOL

echo "root:$PASSWORD" | chpasswd

useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable networking
systemctl enable NetworkManager

mkdir -p /home/$USERNAME/.config

cat <<EOL > /home/$USERNAME/.profile
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
  river
fi
EOL

chown -R $USERNAME:$USERNAME /home/$USERNAME

EOF

sync

echo
read -p "Complete. Reboot? (y/N): " REBOOT_CONFIRM
if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
  reboot
else
  echo "You can reboot later by typing 'reboot'."
fi
