#!/bin/bash

EFIBOOTPATH=/boot/efi/loader/entries
source /home/bhaskar/colors.sh
source /home/bhaskar/spinner.sh
NOCOLOR="\033[0m"
build_dir=/home/bhaskar/latest_kernel_build_`hostname`_`date '+%F'`
get_kernel=/usr/local/bin/secure_kernel_tarball
TM="/usr/bin/time -f"
pkg_dir="/usr/src/packages/RPMS/x86_64"
boot_dir="/boot"

printf "${Reverse}Lets build the new kernel${NOCOLOR}  ..... \n\n"

printf "Hostname: %s\nDate    : %s\nUptime  :%s\n\n"  "$(hostname -s)" "$(date)" "$(uptime)"

printf " Check the latest stable kernel version from ${Bright}${Blue}kernel.org${NOCOLOR} \n\n"
#kernel=`curl -sL https://www.kernel.org/finger_banner | grep '4.18' | awk -F: '{gsub(/ /,"", $0); print $2}'`
kernel=$(curl -s https://www.kernel.org/ | grep -A1 'stable:' | grep -oP '(?<=strong>).*(?=</strong.*)' | grep 5.10)
printf "${Bright}${Green}$kernel${NOCOLOR} \n"

printf "\n Pre-flight check...basic build tools are in the system for kernel build...\n"

ver_linux

if [[ ! -d $build_dir ]];then
   mkdir -p $build_dir
fi

cd $build_dir

printf "Get the kernel from ${Bright}${Blue}kernel.org${NOCOLOR} and this for the ${Underline}*stable* kernel${NOCOLOR} \n\n\n"


#wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$kernel.tar.xz

#printf "Get the ${Bright}${LimeYellow}sign for the kernel${NOCOLOR} ...\n\n"

#wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$kernel.tar.sign

#printf "Get the ${Bright}${Cyan} asc file for verification ${NOCOLOR} ...\n\n"

#wget -c https://cdn.kernel.org/pub/linux/kernel/v4.x/sha256sums.asc

eval ${get_kernel} ${kernel}

printf "\n\n ${Bright}${Magenta}  Make sure we are in the right directory ${NOCOLOR} ...\n\n"

pwd


printf "${Bright}${Magenta} Decompress the downloaded kernel${NOCOLOR} ...\n\n\n"

unxz linux-$kernel.tar.xz


#printf "${Bright}${Green} Lets check the kernel signing${NOCOLOR}...\n\n"

#gpg2 --verify linux-$kernel.tar.sign

#sleep 3

#gpg2 --verify sha256sums.asc

#sleep 3


printf "${Bright}${Cyan} Untar the kernel${NOCOLOR} ...\n\n"

tar -xvf linux-$kernel.tar


if [[ $? -eq 0 ]]; then
printf "${Bright}${Green} Looks alright ..go ahead ${NOCOLOR} \n\n "
else
printf "${Bright}${Red}Nope missing tool ,abort! ${NOCOLOR} \n\n"
fi

printf "\n\n ${Bright}${Yellow} Get into the kernel tree and clean it ${NOCOLOR} ..\n\n\n"

cd linux-$kernel

/usr/bin/notify-send --expire-time=2000 --urgency=critical "The kernel building started"

make  clean && make mrproper

cp /boot/config-$(uname -r) .config

scripts/config --disable DEBUG_KERNEL
grep DEBUG_KERNEL .config
scripts/config --disable DEBUG_INFO
grep DEBUG_INFO .config

make  ARCH=x86_64 olddefconfig


$TM "\t\n\n Elapsed Time : %E \n\n"  /usr/bin/make ARCH=x86_64 V=1 -j `getconf _NPROCESSORS_ONLN` LOCALVERSION=-`hostname` rpm-pkg


if [ $? == 0 ]
then

printf "${Bright}${Green}Done${NOCOLOR} \n\n"

else

printf "${right}${Red}Error encountered${NOCOLOR} \n\n"

fi


printf "Installing the packages.....\n\n\n"

cd $pkg_dir

rpm -ivh --force *.rpm
rpm --addsign *.rpm
rpm --checksig *.rpm

printf "\n\n ${Bright}${Yellow} Fixing the EFI boot entry by copying the kernel to ESP place ${NOCOLOR}...\n\n"
cd $boot_dir
cp vmlinuz-$kernel-1-default-$(hostname) /boot/efi/EFI/Opensuse/
cp initrd-$kernel-1-default-$(hostname) /boot/efi/EFI/Opensuse/

/usr/bin/notify-send --expire-time=2000 --urgency=critical "Copied linux and initrd in EFI directory"

>$EFIBOOTPATH/Opensuse.conf

echo "title Opensuse-Tumbleweed" > $EFIBOOTPATH/Opensuse.conf
echo "linux /EFI/Opensuse/vmlinuz-$kernel-1-default-$(hostname)" >> $EFIBOOTPATH/Opensuse.conf
echo " initrd /EFI/Opensuse/initrd-$kernel-1-default-$(hostname)" >> $EFIBOOTPATH/Opensuse.conf
echo "options root=PARTUUID=d00ebebc-78a0-4400-bbf7-415692185e5b loglevel=3  systemd.show_status=true rw" >> $EFIBOOTPATH/Opensuse.conf

cat $EFIBOOTPATH/Opensuse.conf

/usr/bin/notify-send --expire-time=2000 --urgency=critical "Modified the boot entry"

printf "\n\n ${Bright}${Cyan} Fix the UEFI boot shell script... ${NOCOLOR} \n\n"

echo "\EFI\Opensuse\-$kernel-1-default-$(hostname) --initrd \EFI/Opensuse\initrd-$kernel-1-default-$(hostname) root=PARTUUID=d00ebebc-78a0-4400-bbf7-415692185e5b rw" > /boot/efi/EFI/Opensuse.nsh


cat /boot/efi/EFI/Opensuse.nsh
/usr/bin/notify-send --expire-time=2000 --urgency=critical "Fix the nsh script too"

printf "\n\n ${Bright}${Cyan}Lets clean up the build directory ${NOCOLOR} .....\n\n\n"

#cd ..

(rm -rf $build_dir) &

spinner "$!" "Cleaning...wait.."


exit 0
