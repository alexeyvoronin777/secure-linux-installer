#!/bin/sh

#phisical volume name
VOLUME=/dev/sda
PARTITION="$VOLUME"1
MOUNT_POINT=/mnt

#mode
GRAPHICAL=1
CONSOLE=1
YAOURT_GIT=0

NEW_USER=alan

#calculate size for swap partition
RAM=$(free -m | awk '/^Mem:/{print $2}')
TAIL=$RAM/5
SWAP=$(($RAM+$TAIL))

#applications list
SYSTEM="base grub net-tools sudo"
ACCESSORIES="mc curl gpm unzip jre8-openjdk java-openjfx"
GUI=""
OFFICE=""
DEVELOPMENT="base-devel gcc gdb cmake python clang jdk8-openjdk git subversion mercurial boost"
WEB=""
MEDIA=""
EMULATORS="wine qemu"

if [[ $GRAPHICAL == 1 ]]; then
ACCESSORIES="$ACCESSORIES lilyterm"
GUI="$GUI xorg-server xorg-server-utils xorg-xinit mate mate-extra slim"
DEVELOPMENT="$DEVELOPMENT eclipse-cdt monodevelop qt5"
OFFICE="$OFFICE libreoffice"
WEB="$WEB firefox pidgin skype flashplayer transmission-cli transmission-gtk"
MEDIA="$MEDIA vlc ffmpeg mplayer gimp blender"
fi

if [[ $CONSOLE == 1 ]]; then
GUI="$GUI tmux" #console window manager
DEVELOPMENT="$DEVELOPMENT emacs"
OFFICE=$OFFICE 
WEB="$WEB links profanity transmission-cli"
MEDIA="$MEDIA moc mplayer"
fi

APPLICATIONS="$SYSTEM $ACCESSORIES $GUI $OFFICE $DEVELOPMENT $WEB $MEDIA"

#create encrypted device
cryptsetup luksFormat $PARTITION
cryptSetup luksOpen $PARTITION cryptDevice


#create virtual partitions
pvcreate /dev/mapper/cryptDevice

vgcreate vg /dev/mapper/cryptDevice

lvcreate -L --size 200M vg --name boot
lvcreate -L --size "$SWAP"M vg --name swap
lvcreate -l +100%FREE vg --name root

mkfs.ext2 /dev/mapper/vg-boot
mkfs.ext4 /dev/mapper/vg-root
mkswap /dev/mapper/vg-swap

swapon /dev/mapper/vg-swap
mount /dev/mapper/vg-root $MOUNT_POINT
mkdir $MOUNT_POINT/boot
mount /dev/mapper/vg-boot $MOUNT_POINT/boot

pacstrap $MOUNT_POINT $APPLICATIONS

genfstab -pU $MOUNT_POINT >> $MOUNT_POINT/etc/fstab

# Setup system clock
ln -s $MOUNT_POINT/usr/share/zoneinfo/Europe/Kiev $MOUNT_POINT/etc/localtime
arch-chroot $MOUNT_POINT hwclock --systohc --utc

# Update locale
echo LANG=en_US.UTF-8 >> $MOUNT_POINT/etc/locale.conf
echo LANGUAGE=en_US >> $MOUNT_POINT/etc/locale.conf
echo LC_ALL=C >> $MOUNT_POINT/etc/locale.conf
arch-chroot $MOUNT_POINT locale-gen

#install secure remote shell
arch-chroot $MOUNT_POINT pacman -S openssh --noconfirm
cp ./sshd_config $MOUNT_POINT/etc/ssh/sshd_config
arch-chroot $MOUNT_POINT systemctl enable sshd.service

#set autostart grphical login
if [[ $GRAPHICAL == 1 ]]; then
arch-chroot $MOUNT_POINT systemctl enable slim
fi

#install ports
arch-chroot $MOUNT_POINT "pacman -S abs --noconfirm"
arch-chroot $MOUNT_POINT abs

VBOX=$((lspci) | grep VirtualBox)

if [[ $VBOX != "" ]]; then
#install vbox guests
arch-chroot $MOUNT_POINT pacman -S virtualbox-guest-utils
arch-chroot $MOUNT_POINT systemctl enable vboxservice 
arch-chroot $MOUNT_POINT modprobe -a vboxguest vboxsf vboxvideo
"vboxguest" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
"vboxsf" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
"vboxvideo" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
fi

if [[ $(uname -m) == "x86_64" ]]; then
#install x86_64 bit dependecies
fi

#install yaourt package manager
if [[ $YAOURT_GIT == 1 ]]; then
pacman -S git --noconfirm
git clone https://aur.archlinux.org/package-query.git
cd package-query
makepkg -si
cd ..
git clone https://aur.archlinux.org/yaourt.git
cd yaourt
makepkg -si
cd ..
elif
echo "[archlinuxfr]" >> $MOUNT_POINT/etc/pacman.conf
echo "SigLevel = Never" >> $MOUNT_POINT/etc/pacman.conf
echo "Server = http://repo.archlinux.fr/$arch" >> $MOUNT_POINT/etc/pacman.conf
echo "" >> $MOUNT_POINT/etc/pacman.conf
pacman -Sy yaourt --noconfirm
fi

#configuration initrd
# Add 'ext4' to MODULES
sed -i.bak '/sMODULES=""/MODULES="ext4"/g' $MOUNT_POINT/etc/mkinitcpio.conf
# Add 'encrypt' and 'lvm2' to HOOKS before filesystems

arch-chroot $MOUNT_POINT /usr/bin/mkinitcpio -p linux

#Configuration grub for encryption
sed -i.bak '/sGRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda1:cryptDevice"/g' $MOUNT_POINT/etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> $MOUNT_POINT/etc/default/grub

arch-chroot $MOUNT_POINT /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot $MOUNT_POINT /usr/bin/grub-install $VOLUME

# Set the hostname
echo WORKLINUX > $MOUNT_POINT/etc/hostname

#netwok configuration
arch-chroot $MOUNT_POINT systemctl enable dhcpcd.service
#arch-chroot $MOUNT_POINT systemctl enable dhcpcd@enp0s3.service

#network performance
#/etc/security/limits.conf
#* - nofile 1048576
#/etc/sysctl.conf
# Если используете netfilter/iptables, увеличить лимит нужно и здесь: 
#net.ipv4.netfilter.ip_conntrack_max = 1048576


# Set root password
arch-chroot $MOUNT_POINT passwd

#add new user
arch-chroot $MOUNT_POINT useradd -m -g users -G wheel,video,storage -s /bin/bash $NEW_USER
"$NEW_USER ALL=(ALL) ALL" >> $MOUNT_POINT/etc/sudoers
arch-chroot $MOUNT_POINT passwd $NEW_USER

umount -p $MOUNT_POINT
swapoff -a

reboot

