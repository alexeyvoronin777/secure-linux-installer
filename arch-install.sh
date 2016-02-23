#!/bin/bash
#
# Secure Linux installer script.

#phisical volume name
VOLUME="/dev/sda"
PARTITION="$VOLUME"1
MOUNT_POINT=/mnt
HOSTNAME=WORKLINUX
LVM_GROUP=vg
CRYPT_DEVICE=cryptDevice

#mode
GRAPHICAL=1
CONSOLE=1
YAOURT=1

NEW_USER=alan

#applications list
SYSTEM="grub net-tools sudo ntfs-3g ntfsprogs"
ACCESSORIES="mc curl rsync gpm unzip jre8-openjdk java-openjfx"
GUI=""
OFFICE=""
DEVELOPMENT="base-devel gcc gdb cmake python clang jdk8-openjdk git subversion mercurial"
WEB=""
MEDIA="pulseaudio"
EMULATORS="wine qemu"

if [[ $GRAPHICAL == 1 ]]; then
ACCESSORIES="$ACCESSORIES lilyterm keepassx"
GUI="$GUI xorg-server xorg-server-utils xorg-xinit mate mate-extra slim"
DEVELOPMENT="$DEVELOPMENT eclipse-cpp monodevelop qt5"
OFFICE="$OFFICE libreoffice"
WEB="$WEB firefox pidgin skype flashplayer transmission-cli transmission-gtk claws-mail"
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


########################################
# Convert string for regular expression
# Arguments:
#       Input string
# Returns:
#       None
########################################
adaptation_regular(){
    local pattern="/"
    local newchar="\/"
    local val=${1//$pattern/$newchar}
    echo $val
}


######################################
# Create new user.
# Globals:
#       MOUNT_POINT
# Arguments:
#       User name
# Returns:
#       None
######################################
add_new_user(){
    local $NEW_USER=$1
    arch-chroot $MOUNT_POINT useradd -m -g users\
    -G wheel,video,storage -s /bin/bash $NEW_USER
    echo "$NEW_USER ALL=(ALL) ALL" >> $MOUNT_POINT/etc/sudoers
    echo "Set $NEW_USER password:"
    arch-chroot $MOUNT_POINT passwd $NEW_USER
}

########################################
# Write random values to partition
# Arguments:
#       Partition name
# Returns:
#       None
########################################
write_random_to_partition(){
    local $PARTITION=$1
    echo "Write random values on partition..."
    dd if=/dev/urandom of=$PARTITION
    echo "Done."
}

########################################
# Up-protection password
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
up_protection_password(){
    #disable root login
    sed 's/tty/#tty/g' $MOUNT_POINT/etc/securetty > $MOUNT_POINT/etc/securetty.new
    cp $MOUNT_POINT/etc/securetty.new $MOUNT_POINT/etc/securetty
    rm $MOUNT_POINT/etc/securetty.new    
    echo "auth required pam_tally.so deny=2 unlock_time=600 onerr=succeed file=/var/log/faillog" >> $MOUNT_POINT/etc/pam.d/system-login
    echo "password required pam_cracklib.so retry=2 minlen=10 difok=6 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1" >> $MOUNT_POINT/etc/pam.d/passwd
    echo "password required pam_unix.so use_authtok sha512 shadow" >> $MOUNT_POINT/etc/pam.d/passwd
    echo "auth		required	pam_wheel.so use_uid" >> $MOUNT_POINT/etc/pam.d/su
    echo "auth		required	pam_wheel.so use_uid" >> $MOUNT_POINT/etc/pam.d/su-l
}

########################################
# Netowork configuration
# Arguments:
#       None
# Returns:
#       None
########################################
network_configuration(){
   echo "network configuration..."
   arch-chroot $MOUNT_POINT systemctl enable dhcpcd.service
   echo "Done."
}

########################################
# Update locales
# Arguments:
#       None
# Returns:
#       None
########################################
update_locales(){
    echo "update locales..."
    echo LANG=en_US.UTF-8 >> $MOUNT_POINT/etc/locale.conf
    echo LANGUAGE=en_US >> $MOUNT_POINT/etc/locale.conf
    echo LC_ALL=C >> $MOUNT_POINT/etc/locale.conf
    arch-chroot $MOUNT_POINT locale-gen
    echo "Done."
}

########################################
# Install Secure Shell
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
ssh_install(){
    echo "install ssh..."
    arch-chroot $MOUNT_POINT pacman -S openssh --noconfirm
    arch-chroot $MOUNT_POINT systemctl enable sshd.service
    echo "Done."
}

########################################
# Setup time
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
setup_time(){
    echo "setup time..."
    ln -s $MOUNT_POINT/usr/share/zoneinfo/Europe/Kiev $MOUNT_POINT/etc/localtime
    arch-chroot $MOUNT_POINT hwclock --systohc --utc
    echo "Done."
}

########################################
# Setup mount pointes
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
setup_mount_pointes(){
    echo "setup mount pointes..."
    genfstab -pU $MOUNT_POINT >> $MOUNT_POINT/etc/fstab
    echo "Done."
}

########################################
# Install VirtualBox modules
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
install_vbox_modules(){
    local VBOX=$((lspci) | grep VirtualBox)

    if [[ $VBOX != "" ]]; then
    echo "Install VirtualBox modules..."
    #install vbox guests
    arch-chroot $MOUNT_POINT pacman -S virtualbox-guest-utils --noconfirm
    arch-chroot $MOUNT_POINT systemctl enable vboxservice 
    arch-chroot $MOUNT_POINT modprobe -a vboxguest vboxsf vboxvideo
    echo "vboxguest" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
    echo "vboxsf" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
    echo "vboxvideo" >> $MOUNT_POINT/etc/modules-load.d/virtualbox.conf
    fi
    echo "Done."
}

########################################
# Install ports
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
install_ports(){
    echo "Install ports..."
    arch-chroot $MOUNT_POINT pacman -S abs --noconfirm
    arch-chroot $MOUNT_POINT abs
    echo "Done."
}

########################################
# Install addinitional package manager
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
install_addinitional_package_manager(){
    echo "Install addinitional package manager..."
    echo "" >> $MOUNT_POINT/etc/pacman.conf
    echo "[archlinuxfr]" >> $MOUNT_POINT/etc/pacman.conf
    echo "SigLevel = Never" >> $MOUNT_POINT/etc/pacman.conf
    echo "Server = http://repo.archlinux.fr/\$arch" >> $MOUNT_POINT/etc/pacman.conf
    echo "" >> $MOUNT_POINT/etc/pacman.conf
    arch-chroot $MOUNT_POINT pacman -Sy yaourt --noconfirm
    arch-chroot $MOUNT_POINT yaourt -Syua --noconfirm
    echo "Done."
}

########################################
# Setup host name
# Globals:
#   MOUNT_POINT
# Arguments:
#       host name
# Returns:
#       None
########################################
setup_hostname(){
    echo "Setup hostname..."
    local $HOSTNAME=$1
    echo $HOSTNAME > $MOUNT_POINT/etc/hostname
    echo "Done."
}

########################################
# Setup multilibrary
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
setup_multilibrary(){
    echo "Setup multilibrary..."
    if [[ $(uname -m) == x86_64 ]]; then
    echo "" >> $MOUNT_POINT/etc/pacman.conf
    echo "[multilib]" >> $MOUNT_POINT/etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist" >> $MOUNT_POINT/etc/pacman.conf
    echo "" >> $MOUNT_POINT/etc/pacman.conf
    arch-chroot $MOUNT_POINT pacman -Syu
    fi
    echo "Done."
}

########################################
# Install core
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
install_core(){
    echo "Install core..."
    pacstrap $MOUNT_POINT base
    echo "Done."
}

#########################################
# Configuration bash prifles for new user
# and root.
# Globals:
#   MOUNT_POINT
#   NEW_USER
# Arguments:
#       None
# Returns:
#       None
#########################################
setup_bash_profile(){
    echo "Setup bash profile..."
    sed 's/PS1/#PS1/g' $MOUNT_POINT/etc/securetty > $MOUNT_POINT/home/$NEW_USER/.bashrc.new
    cp $MOUNT_POINT/home/$NEW_USER/.bashrc.new $MOUNT_POINT/home/$NEW_USER/.bashrc
    rm $MOUNT_POINT/home/$NEW_USER/.bashrc
    echo "PS1='\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] '" >> $MOUNT_POINT/home/$NEW_USER/.bashrc
    echo "PS1='\[\e[1;31m\][\u@\h \W]\$\[\e[0m\] '" >> $MOUNT_POINT/root/.bashrc
    echo "Done."
}

########################################
# Install user applications
# Globals:
#   MOUNT_POINT
#   APPLICATIONS
# Arguments:
#       None
# Returns:
#       None
########################################
install_user_applications(){
    echo "Install user applications..."
    arch-chroot $MOUNT_POINT pacman -S $APPLICATIONS --noconfirm
    echo "Done."
}

########################################
# Create and mount LVM partitions
# Globals:
#   MOUNT_POINT
#   LVM_GROUP
#   CRYPT_DEVICE
# Arguments:
#       None
# Returns:
#       None
########################################
create_and_mount_lvm_partitions(){
    #calculate size for swap partition
    local RAM=$(free -m | awk '/^Mem:/{print $2}')
    local TAIL=$RAM/5
    local SWAP=$(($RAM+$TAIL))
    echo "Create and mount LVM partitions..."
    #create virtual partitions
    pvcreate /dev/mapper/$CRYPT_DEVICE
    
    vgcreate $LVM_GROUP /dev/mapper/$CRYPT_DEVICE
    
    lvcreate -L 200M $LVM_GROUP --name boot
    lvcreate -L "$SWAP"M $LVM_GROUP --name swap
    lvcreate -l +100%FREE $LVM_GROUP --name root
    
    mkfs.ext2 /dev/mapper/$LVM_GROUP-boot
    mkfs.ext4 /dev/mapper/$LVM_GROUP-root
    mkswap /dev/mapper/$LVM_GROUP-swap
    
    swapon /dev/mapper/$LVM_GROUP-swap
    mount /dev/mapper/$LVM_GROUP-root $MOUNT_POINT
    mkdir $MOUNT_POINT/boot
    mount /dev/mapper/$LVM_GROUP-boot $MOUNT_POINT/boot
    echo "Done."
}

########################################
# Configuration initrd
# Globals:
#   MOUNT_POINT
# Arguments:
#       None
# Returns:
#       None
########################################
configuration_initrd(){
    echo "Configuration initrd..."
    # Add 'ext4' to MODULES
    sed 's/MODULES=""/MODULES="ext4"/g' $MOUNT_POINT/etc/mkinitcpio.conf > $MOUNT_POINT/etc/mkinitcpio.conf.new
    cp $MOUNT_POINT/etc/mkinitcpio.conf.new $MOUNT_POINT/etc/mkinitcpio.conf
    rm $MOUNT_POINT/etc/mkinitcpio.conf.new
    # Add 'encrypt' and 'lvm2' to HOOKS before filesystems
    sed 's/keyboard fsck/keyboard fsck encrypt lvm2/g' $MOUNT_POINT/etc/mkinitcpio.conf > $MOUNT_POINT/etc/mkinitcpio.conf.new
    cp $MOUNT_POINT/etc/mkinitcpio.conf.new $MOUNT_POINT/etc/mkinitcpio.conf
    rm $MOUNT_POINT/etc/mkinitcpio.conf.new
    
    arch-chroot $MOUNT_POINT /usr/bin/mkinitcpio -p linux   
    echo "Done."
}

########################################
# Setup and install grub
# Globals:
#   MOUNT_POINT
#   VOLUME
# Arguments:
#       None
# Returns:
#       None
########################################
setup_and_install_grub(){
    echo "Setup and install grub..."
    sed 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice='"$(adaptation_regular $PARTITION)"':'"$CRYPT_DEVICE"'"''/g' $MOUNT_POINT/etc/default/grub > $MOUNT_POINT/etc/default/grub.new
    cp $MOUNT_POINT/etc/default/grub.new $MOUNT_POINT/etc/default/grub
    rm $MOUNT_POINT/etc/default/grub.new
    echo "GRUB_ENABLE_CRYPTODISK=y" >> $MOUNT_POINT/etc/default/grub
    #echo 'GRUB_BACKGROUND="/root/1.png"'' >> $MOUNT_POINT/etc/default/grub
    arch-chroot $MOUNT_POINT grub-mkconfig -o /boot/grub/grub.cfg
    arch-chroot $MOUNT_POINT grub-install $VOLUME
    echo "Done."
}

########################################
# Setup key for once login
# Globals:
#   MOUNT_POINT
#   PARTITION
# Arguments:
#       None
# Returns:
#       None
########################################
setup_once_login(){
    local KEY_PATH=/crypto_keyfile.bin
    echo "Setup key for once login..."
    echo "Generate random key in root."
    dd bs=512 count=4 if=/dev/urandom of="$MOUNT_POINT""$KEY_PATH"
    echo "Add key to encrypt partitition..."
    cryptsetup luksAddKey $PARTITION $KEY_PATH
    echo "Add key to initrd..."
    # Add 'encrypt' and 'lvm2' to HOOKS before filesystems
    sed 's/FILES=""/FILES="'"$(adaptation_regular $KEY_PATH)"'"/g' $MOUNT_POINT/etc/mkinitcpio.conf > $MOUNT_POINT/etc/mkinitcpio.conf.new
    cp $MOUNT_POINT/etc/mkinitcpio.conf.new $MOUNT_POINT/etc/mkinitcpio.conf
    rm $MOUNT_POINT/etc/mkinitcpio.conf.new
    arch-chroot mkinitcpio -p linux
    echo "Done."
}

#write random values on partition
write_random_to_partition $PARTITION

#create encrypted device
cryptsetup luksFormat $PARTITION
cryptsetup luksOpen $PARTITION $CRYPT_DEVICE


#create virtual partitions
create_and_mount_lvm_partitions

install_core

setup_multilibrary

#install applications
install_user_applications

#setup mount pointes
setup_mount_pointes

# Setup system clock
setup_time

# Update locale
update_locales

#install secure remote shell
ssh_install

#set autostart graphical login
if [[ $GRAPHICAL == 1 ]]; then
arch-chroot $MOUNT_POINT pacman -S slim-themes archlinux-themes-slim --noconfirm
arch-chroot $MOUNT_POINT systemctl enable slim
fi

#set autostart mouse in console
if [[ $CONSOLE == 1 ]]; then
arch-chroot $MOUNT_POINT systemctl enable gpm
fi

#install ports
install_ports

install_vbox_modules

#install yaourt package manager
if [[ $YAOURT == 1 ]]; then
install_addinitional_package_manager
fi

#configuration initrd
configuration_initrd

#Configuration grub for encryption
setup_and_install_grub

# Set the hostname
setup_hostname

#setup permissions
chmod 700 $MOUNT_POINT/boot $MOUNT_POINT/etc/{iptables,arptables} 

#user password protection
up_protection_password

#netwok configuration
network_configuration

#network performance
#/etc/security/limits.conf
#* - nofile 1048576
#/etc/sysctl.conf
#net.ipv4.netfilter.ip_conntrack_max = 1048576

#copy configs
echo "Configuration..."
cp -R ./etc $MOUNT_POINT/

# Set root password
echo "Set root password:"
arch-chroot $MOUNT_POINT passwd

#add new user
add_new_user $NEW_USER

#setup bash profile. Need after add new user
setup_bash_profile

#set once login
setup_once_login

swapoff -a
umount -R $MOUNT_POINT
cryptsetup luksClose $CRYPT_DEVICE

#reboot

