#!/bin/sh

#phisical volume name
VOLUME=/dev/sda
PARTITION="$VOLUME"1
MOUNT_POINT=/mnt

#mode
GRAPHICAL=1
CONSOLE=1
YAOURT=0

NEW_USER=alan

#calculate size for swap partition
RAM=$(free -m | awk '/^Mem:/{print $2}')
TAIL=$RAM/5
SWAP=$(($RAM+$TAIL))

#applications list
SYSTEM="base grub net-tools sudo"
ACCESSORIES="mc curl rsync gpm unzip jre8-openjdk java-openjfx"
GUI=""
OFFICE=""
DEVELOPMENT="base-devel gcc gdb cmake python clang jdk8-openjdk git subversion mercurial"
WEB=""
MEDIA="pulseaudio"
EMULATORS="wine qemu"

if [[ $GRAPHICAL == 1 ]]; then
ACCESSORIES="$ACCESSORIES lilyterm"
GUI="$GUI xorg-server xorg-server-utils xorg-xinit mate mate-extra slim"
DEVELOPMENT="$DEVELOPMENT eclipse-cpp monodevelop qt5"
OFFICE="$OFFICE libreoffice"
WEB="$WEB firefox pidgin skype flashplayer transmission-cli transmission-gtk"
MEDIA="$MEDIA vlc ffmpeg mplayer gimp blender pavucontrol"
fi

if [[ $CONSOLE == 1 ]]; then
GUI="$GUI tmux" #console window manager
DEVELOPMENT="$DEVELOPMENT emacs"
OFFICE=$OFFICE 
WEB="$WEB links profanity transmission-cli"
MEDIA="$MEDIA moc mplayer ponymix"
fi

APPLICATIONS="$SYSTEM $ACCESSORIES $GUI $OFFICE $DEVELOPMENT $WEB $MEDIA"

#write random values on partition
echo "Write random values on partition..."
dd if=/dev/urandom of=$PARTITION
echo "Done."

#create encrypted device
cryptsetup luksFormat $PARTITION
cryptsetup luksOpen $PARTITION cryptDevice


#create virtual partitions
pvcreate /dev/mapper/cryptDevice

vgcreate vg /dev/mapper/cryptDevice

lvcreate -L 200M vg --name boot
lvcreate -L "$SWAP"M vg --name swap
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
arch-chroot $MOUNT_POINT pacman -S abs --noconfirm
arch-chroot $MOUNT_POINT abs

VBOX=$((lspci) | grep VirtualBox)

if [[ $VBOX != "" ]]; then
#install vbox guests
arch-chroot $MOUNT_POINT pacman -S virtualbox-guest-utils --noconfirm
arch-chroot $MOUNT_POINT systemctl enable vboxservice 
arch-chroot $MOUNT_POINT modprobe -a vboxguest vboxsf vboxvideo
echo "vboxguest" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
echo "vboxsf" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
echo "vboxvideo" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
fi

#install yaourt package manager
if [[ $YAOURT == 1 ]]; then
echo "" >> $MOUNT_POINT/etc/pacman.conf
echo "[archlinuxfr]" >> $MOUNT_POINT/etc/pacman.conf
echo "SigLevel = Never" >> $MOUNT_POINT/etc/pacman.conf
echo "Server = http://repo.archlinux.fr/\$arch" >> $MOUNT_POINT/etc/pacman.conf
echo "" >> $MOUNT_POINT/etc/pacman.conf
arch-chroot $MOUNT_POINT pacman -Sy yaourt --noconfirm
arch-chroot $MOUNT_POINT yaourt -Syua --noconfirm
fi

#configuration initrd
# Add 'ext4' to MODULES
sed -i.bak '/sMODULES=""/MODULES="ext4"/g' $MOUNT_POINT/etc/mkinitcpio.conf
# Add 'encrypt' and 'lvm2' to HOOKS before filesystems

arch-chroot $MOUNT_POINT /usr/bin/mkinitcpio -p linux

#Configuration grub for encryption
sed -i.bak '/sGRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda1:cryptDevice"/g' $MOUNT_POINT/etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> $MOUNT_POINT/etc/default/grub

arch-chroot $MOUNT_POINT grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot $MOUNT_POINT grub-install $VOLUME

# Set the hostname
echo WORKLINUX > $MOUNT_POINT/etc/hostname

#set timeout for console
echo 'TMOUT="$(( 60*10 ))";' >> $MOUNT_POINT/etc/profile.d/shell-timeout.sh
echo '[ -z "$DISPLAY" ] && export TMOUT;' >> $MOUNT_POINT/etc/profile.d/shell-timeout.sh
echo 'case $( /usr/bin/tty ) in' >> $MOUNT_POINT/etc/profile.d/shell-timeout.sh
echo '	/dev/tty[0-9]*) export TMOUT;;' >> $MOUNT_POINT/etc/profile.d/shell-timeout.sh
echo 'esac ' >> $MOUNT_POINT/etc/profile.d/shell-timeout.sh
echo ' ' >> $MOUNT_POINT/etc/profile.d/shell-timeout.sh

#setup permissions
chmod 700 $MOUNT_POINT/boot $MOUNT_POINT/etc/{iptables,arptables} 

#disable root login
sed -i.bak '/stty/#tty/g' $MOUNT_POINT/etc/securetty

#password bruteforce protection
echo "password required pam_cracklib.so retry=2 minlen=10 difok=6 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1" >> $MOUNT_POINT/etc/pam.d/login
echo "password required pam_unix.so use_authtok sha512 shadow" >> $MOUNT_POINT/etc/pam.d/login
echo "password	required pam_unix.so sha512 shadow nullok rounds=65536" >> $MOUNT_POINT/etc/pam.d/passwd

#netwok configuration
arch-chroot $MOUNT_POINT systemctl enable dhcpcd.service
#arch-chroot $MOUNT_POINT systemctl enable dhcpcd@enp0s3.service

#network performance
#/etc/security/limits.conf
#* - nofile 1048576
#/etc/sysctl.conf
#net.ipv4.netfilter.ip_conntrack_max = 1048576


# Set root password
echo "Set root password:"
arch-chroot $MOUNT_POINT passwd

#add new user
arch-chroot $MOUNT_POINT useradd -m -g users -G wheel,video,storage -s /bin/bash $NEW_USER
echo "$NEW_USER ALL=(ALL) ALL" >> $MOUNT_POINT/etc/sudoers
echo "Set $NEW_USER password:"
arch-chroot $MOUNT_POINT passwd $NEW_USER

umount -R $MOUNT_POINT
swapoff -a

#reboot

