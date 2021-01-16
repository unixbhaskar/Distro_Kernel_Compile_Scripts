#!/bin/bash
source /home/bhaskar/colors.sh
NOCOLOR="\033[0m"
#DT=`date '+%d%m%Y'`
BASEPATH=/home/bhaskar/latest_kernel_build_$(hostname)_$(date '+%F')
EFIBOOTDIR=/boot/efi/EFI/debian/
EFIMENUENTRY=/boot/efi/loader/entries/Debian.conf
get_kernel=/usr/local/bin/secure_kernel_tarball

printf "\n\n ${Reverse}################ Building Custom Kernel ${NOCOLOR}################ \n\n"


mkdir -p $BASEPATH

printf "${Bright}${White}Created the ${BASEPATH} ${NOCOLOR} \n\n"

cd $BASEPATH

printf "Hostname: %s\nDate    : %s\nUptime  :%s\n\n"  "$(hostname -s)" "$(date)" "$(uptime)"

printf " Check the latest stable kernel version from ${Bright}${Blue}kernel.org${NOCOLOR} \n\n"
#kernel=`curl -sL https://www.kernel.org/finger_banner | grep '4.18' | awk -F: '{gsub(/ /,"", $0); print $2}'`
kernel=`curl -s https://www.kernel.org/ | grep -A1 'stable' | grep -oP '(?<=strong>).*(?=</strong.*)' | grep 5.10`
printf "${Bright}${Green}$kernel${NOCOLOR}\n\n"


printf "\n\n${Bright}${Magenta} Make sure we are in the right directory ${NOCOLOR}...\n\n"


printf "${Reverse}$PWD ${NOCOLOR} \n\n"

printf "Get the kernel from ${Bright}${Blue}kernel.org${NOCOLOR} and this for the ${Underline}*stable* kernel${NOCOLOR} \n\n\n"


#wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$kernel.tar.xz

#printf "Get the ${Bright}${LimeYellow}sign for the kernel${NOCOLOR} ...\n\n"

#wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$kernel.tar.sign

#printf "Get the ${Bright}${Cyan} asc file for verification ${NOCOLOR} ...\n\n"

#wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/sha256sums.asc

eval ${get_kernel} ${kernel}

printf "${Bright}${LimeYellow}Decompress the kernel source ${NOCOLOR}..\n\n"

tar -xJvf linux-$kernel.tar.xz

#printf "${Bright}${Magenta}Verify the GPG signature on the kernel file${NOCOLOR}...\n\n"

#gpg2 --verify linux-$kernel.tar.sign
#gpg2 --verify sha256sums.asc

cd linux-$kernel

        printf "\n\n##################${Reverse}Configure the kernel ${NOCOLOR} ######## \n\n\n"

printf "\n\n${Bright}${LimeYellow}Make clean and make mrproper on it ${NOCLOR}......\n\n"

make clean && make mrproper


printf "${Bright}${PowderBlue}Create a .config file,copying over the existing one ${NOCOLOR}....\n\n"

cp -v /boot/config-`uname -r` .config



printf "${Bright}${Red}Taking away faulty option for custom kernel build${NOCOLOR}..\n\n"

scripts/config --disable system_trusted_keys

grep CONFIG_SYSTEM_TRUSTED_KEYS .config


printf  "\n${Yellow} Disabling DEBUG INFO${NOCOLOR} . . .\n\n"

scripts/config --disable DEBUG_INFO

printf "${Green}Done${NOCOLOR}\n\n"

printf "${Bright}${Blue}Run make olddefconfig on it ${NOCOLOR}....\n\n"

make olddefconfig


printf "${Bright}${Cyan}######################### Lets build the kernel #####################################${NOCOLOR}....\n\n\n"

/usr/bin/time -f "\n\n\tTime Elapsed: %E\n\n" make -j `getconf _NPROCESSORS_ONLN` deb-pkg

printf "\n\n\n ${Bright}${Green}Install the generated packages aka kernel,headers,modules et al ${NOCOLOR}\n\n\n"

cd ..

dpkg -i *.deb 


printf "${Bright}${Cyan}Copy kernel,initrd to EFI directory ${NOCOLOR}.....\n\n\n"

cd /boot

cp -v /boot/vmlinuz-$kernel $EFIBOOTDIR
cp -v /boot/initrd.img-$kernel $EFIBOOTDIR


printf "\n\n\n${Bright}${PowderBlue} Fix the boot entry ${NOCOLOR}...\n\n\n"

echo "title Debian" > $EFIMENUENTRY
echo "linux /EFI/debian/vmlinuz-$kernel" >> $EFIMENUENTRY
echo "initrd /EFI/debian/initrd.img-$kernel" >> $EFIMENUENTRY
echo "options root=PARTUUID=ad5ef658-ccc9-46a5-8363-107a8e5e7d15  loglevel=3  systemd.show_status=true ifname.net=0 rw" >> $EFIMENUENTRY

printf "\n\n${Bright}${Green}Take a look at it ${NOCOLOR}...\n\n\n"

cat $EFIMENUENTRY

printf "\n\n ${Bright}${Cyan} Fix the UEFI boot shell script ... ${NOCOLOR} \n\n"

echo " \EFI\debian\vmlinuz-$kernel root=PARTUUID=ad5ef658-ccc9-46a5-8363-107a8e5e7d15  loglevel=3  systemd.show_status=true rw initrd=\EFI\debian\initrd.img-$kernel" > /boot/efi/EFI/debian.nsh

cat /boot/efi/EFI/debian.nsh

printf "\n\n ${Bright}${LimeYellow} Removing the build directory...wait .. ${NOCOLOR} \n\n"

rm -rf $BASEPATH
exit 0
