#!/bin/bash

#This script information based on this wiki page : https://wiki.archlinux.org/index.php/Kernels/Arch_Build_System

NOCOLOR="\033[0m"
EFIBOOTDIR=/boot/efi/EFI/ArchLinux
DT=$(date '+%d%m%Y')
EFIBOOTENTRY=/boot/efi/loader/entries
source /home/bhaskar/colors.sh
build_dir=/home/bhaskar/latest_kernel_$(hostname)_$DT
TM="/usr/bin/time -f"
#MAKE="make ARCH=x86_64 -j $(getconf _NPROCESSORS_ONLN)"

printf "${Bright}${Red}This script is running to autome the custom/latest kernel build process...have patience${NOCOLOR} \n\n\n"

printf "Hostname: %s\nDate    : %s\nUptime  :%s\n\n"  "$(hostname -s)" "$(date)" "$(uptime)"


printf "Get the latest kernel version from ${Blue}kernel.org \n\n\n"
kernel=$(curl -s https://www.kernel.org/ | grep -A1 'stable:' | grep -oP '(?<=strong>).*(?=</strong.*)' | grep 5.10)
printf "${Bright}${GREEN}$kernel${NOCOLOR} \n"

printf "Create a directory to hold and download the latest kernel from ${Blue}kernel.org${NOCOLOR} \n\n\n"

if [[ ! -d $build_dir ]];then
   printf "${Bright}${Green}Created it ${NOCOLOR} \n\n"
    mkdir -p $build_dir
else
   printf "${Bright}${LimeYellow}Already exists! ${NOCOLOR} \n\n"
fi

printf "\n\n Get into it...\n\n\n"

cd $build_dir
pwd

printf "Checking out latest linux from ${Blue}kernel.org${NOCOLOR} \n\n\n\n"
asp update linux
asp checkout linux

if [[ $? == 0 ]];then
   printf "${GREEN}Alright.. continue...${NOCOLOR}\n\n\n"
else
  printf "${RED}Nope abort!${NOCOLOR}\n\n\n"
   exit 1
fi

printf "*********${Bright}${Cyan}Configuring PKGBUILD${NOCOLOR}********** \n\n\n\n"

printf "${LimeYellow}Customizing few varibles in the PKGBUILD file...${NOCOLOR}\n\n\n\n"

cd linux/repos/core-x86_64/

sudo zcat /proc/config.gz > config

#Disable the kernel debug option for quick compile time 
cd src/$kernel-arch1/
scripts/config --disable DEBUG_KERNEL .config 
cd ../../ 

#sed -i 's/pkgbase=linux/#pkgbase=linux/' PKGBUILD

sed -i "s/pkgbase=linux/pkgbase=$(hostname)-$(echo $kernel) /"  PKGBUILD
pkgver=$(grep "pkgver" PKGBUILD | head -1)
sed -i "s/$(echo $pkgver)/pkgver=$(echo $kernel) /" PKGBUILD

#sed -i "/pkgbase=linux-custom/s/^#/pkgbase=$(hostname)-$(echo $kernel) /"  PKGBUILD

#srcver=$(grep "_srcver=" PKGBUILD | head -1)

sed -i '6d' PKGBUILD
sed -i '6i _srcver=${pkgver%%%.*}-arch1 '  PKGBUILD
#cn=$(echo $kernel | cut -d"." -f1-2)
sed -i '17d' PKGBUILD
sed -i '17i _srcname=${pkgver%%%.*}-arch1'  PKGBUILD

#fixed_url="\"$_srcname::git+https://git.archlinux.org/linux.git?signed#tag=v$_srcver\""
#actual_url="\"\$_srcname::https://git.archlinux.org/linux.git/snapshot/\$_srcver.tar.xz\""
sed -i '19d' PKGBUILD
sed -i '19i \"$_srcname::https://git.archlinux.org/linux.git/snapshot/\$_srcver.tar.gz\"' PKGBUILD
sed -i '30d' PKGBUILD
sed -i '30i export KBUILD_BUILD_HOST=Bhaskar_ThinkPad_x250' PKGBUILD
#sed -i  "s/$(echo $fixed_url)/$(echo $actual_url) /" PKGBUILD
sed -i '31d' PKGBUILD
sed -i '31i export KBUILD_BUILD_USER=Bhaskar' PKGBUILD

#sed -i "s/$(echo $patch_version)/pkgver=$(echo $kernel) /" PKGBUILD

sed -i 's/#make oldconfig/make olddefconfig/' PKGBUILD
sed -i '61d' PKGBUILD
sed -i '61i make V=1 ARCH=x86_64 -j4  bzImage modules' PKGBUILD
sed -i '62d' PKGBUILD 
sed -i '169,186 s/^/#/' PKGBUILD
sed -i '187i pkgname=("$pkgbase" "$pkgbase-headers")' PKGBUILD 
sed -i '189d' PKGBUILD
printf "As we have change the PKGBUILD file ,we need to generate the new ${Magenta}CHECKSUM the file .... ${NOCOLOR} \n\n\n"

#makepkg -g

updpkgsums


printf "\n\n\n Lets do the ${Bright}${Green}compiling now ${NOCOLOR} ....\n\n\n"

$TM "\t\n\n Elapsed Time : %E \n\n" makepkg -s

/usr/bin/notify-send --urgency=critical 'Kernel building done'

printf "Install the generated ${PowderBlue}headers,${PowderBlue}kernel and ${PowderBlue}doc packages with pacman .. ${NOCOLOR} \n\n\n"


sudo pacman -U  --noconfirm $(hostname)-$kernel-$kernel-1-x86_64.pkg.tar.zst

sudo pacman -U --noconfirm $(hostname)-$kernel-headers-$kernel-1-x86_64.pkg.tar.zst

#sudo pacman -U  --noconfirm $(hostname)-$kernel-docs-$kernel-1-x86_64.pkg.tar.zst


printf "\n\n\n Done..now copy over the image to ${Yellow}EFI dir..${NOCOLOR} \n\n\n\n"

sudo cp -v /boot/vmlinuz-$(hostname)-$kernel $EFIBOOTDIR
sudo cp -v /boot/initramfs-$(hostname)-$kernel.img $EFIBOOTDIR


printf "${Bright}${Blue}Fixed the boot entry now ${NOCOLOR}...\n\n\n\n"

echo "title ArchLinux" | sudo tee  $EFIBOOTENTRY/ArchLinux.conf
echo "linux /EFI/ArchLinux/vmlinuz-$(hostname)-$kernel" | sudo tee -a $EFIBOOTENTRY/ArchLinux.conf
echo "initrd /EFI/ArchLinux/initramfs-$(hostname)-$kernel.img" | sudo tee -a $EFIBOOTENTRY/ArchLinux.conf
echo "options root=PARTUUID=9e3d2f9a-4846-3049-97fc-b5e5c61820ae  loglevel=3  systemd.show_status=true rw" | sudo tee -a $EFIBOOTENTRY/ArchLinux.conf

printf "\n\n\n ${Bright}${Green} Modified the UEFI script... ${NOCOLOR} \n\n"

echo "\EFI\ArchLinux\vmlinuz-$(hostname)-$kernel root=PARTUUID=9e3d2f9a-4846-3049-97fc-b5e5c61820ae  loglevel=3  systemd.show_status=true rw initrd=\EFI\ArchLinux\initramfs-$(hostname)-$kernel.img" | sudo tee  /boot/efi/EFI/archlinux.nsh

exit 0


