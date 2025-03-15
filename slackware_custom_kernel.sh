#!/usr/bin/env bash


get_make=$(command -v make)
get_elapsed_time="/usr/bin/time -f"
untar_it="tar -xJvf"
existing_config_file="/boot/config-$(uname -r)"
build_dir="/home/bhaskar/latest_kernel_build_$(hostname)_$(date '+%F')"
get_it=$(command -v secure_kernel_tarball)
EFIMENUENTRY="/boot/efi/loader/entries"
EFIBOOTDIR="/boot/efi/"
NOTIFY=$(command -v notify-send)
NOCOLOR="\033[0m"
LOCAL_BIN="/usr/local/bin"
dracut=$(command -v dracut)
clang="CC=clang"
make_llvm="LLVM=1"
llvm_assm="LLVM_IAS=1"
arch_build_dir=/home/bhaskar/archlinux_custom_kernel_build

if [[ $UID -ne 0 ]];then

	echo You need superuser privilage to run this script.
	exit 1
fi

source /home/bhaskar/spinner.sh
clear

cat << "EOF"
  _  __                    _
 | |/ /___ _ __ _ __   ___| |
 | ' // _ \ '__| '_ \ / _ \ |
 | . \  __/ |  | | | |  __/ |
 |_|\_\___|_|  |_| |_|\___|_|_ _       _   _
  / ___|___  _ __ ___  _ __ (_) | __ _| |_(_) ___  _ __
 | |   / _ \| '_ ` _ \| '_ \| | |/ _` | __| |/ _ \| '_ \
 | |__| (_) | | | | | | |_) | | | (_| | |_| | (_) | | | |
  \____\___/|_| |_| |_| .__/|_|_|\__,_|\__|_|\___/|_| |_|
                      |_|
EOF

if [[ ! -d $build_dir ]];then
	mkdir -p $build_dir
fi

cd $build_dir

#if [[ $get_it == "" ]];then
#	curl  -o $LOCAL_BIN/secure_kernel_tarball https://git.kernel.org/pub/scm/linux/kernel/git/mricon/korg-helpers.git/plain/get-verified-tarball
#	chmod +x $LOCAL_BIN/secure_kernel_tarball
#	sed -i '16d'  $LOCAL_BIN/secure_kernel_tarball
#	sed -i "16i TARGETDIR=$build_dir" $LOCAL_BIN/secure_kernel_tarball
#fi




slackware_kernel_build() {

#Download the kernel

which_kernel

eval ${get_it} ${kernel}

#Untar it
$untar_it linux-$kernel.tar.xz

#Get into the kernel direcory
cd linux-$kernel

#Check for required tools to build kernel
scripts/ver_linux

#Copying the existing system running kernel config
cp $existing_config_file .config

# Take away the DEBUG options for faster compile
scripts/config --disable DEBUG_KERNEL
grep DEBUG_KERNEL .config

#Similar vein like above, for faster compile time
scripts/config --disable DEBUG_INFO
grep DEBUG_INFO .config

#Make old kernel config set as well
#$get_make olddefconfig

yes '' | make localmodconfig

printf "Then make it ...\n\n"

$get_elapsed_time "\t\n\n Elapsed time: %E\n\n" $get_make V=1 ARCH=x86_64 -j$(getconf _NPROCESSORS_ONLN) LOCALVERSION=-$(hostname)


$NOTIFY --urgency=critical 'Kernel compilation done'

if [[ $? == 0 ]];then

printf "Done\n\n"

else

printf "Error encountered\n\n"

fi

printf "Installing the modules ..\n\n"

$get_make modules_install

$NOTIFY --urgency=critical 'Modules install done'

printf "\n\n Copying the build kernel to boot directory\n\n"

cp arch/x86/boot/bzImage /boot/vmlinuz-$kernel-$(hostname)

$NOTIFY --urgency=critical 'Kernel install to local boot dir'


printf "Cross check the item ...\n\n"

ls -al /boot/vmlinuz-*

printf "\n\n Copy the System.map file to /boot dir\n\n"

cp System.map /boot/System.map-$kernel-$(hostname)

printf "Copying the .config file to /boot dir$ \n\n"

cp .config /boot/config-$kernel-$(hostname)

printf "Make sure we are in right directory  ..\n\n"
boot="/boot"
cd "$boot"
pwd

printf "Lets relink System.map,config,huge,generic and normal against the new kernel! ... \n\n"
unlink System.map
ln -s Systeme.map-$kernel-$(hostname)  System.map

unlink config
ln -s config-$kernel-$(hostname) config

unlink vmlinuz
ln -s vmlinuz-$kernel-$(hostname) vmlinuz

unlink vmlinuz-huge
ln -s vmlinuz-$kernel-$(hostname) vmlinuz-huge

unlink vmlinuz-generic
ln -s vmlinuz-$kernel-$(hostname) vmlinuz-generic

find . -maxdepth 1 -type l -ls


printf "Copying the image to EFI directory ....\n\n"

cp -v /boot/vmlinuz-$kernel-$(hostname) $EFIBOOTDIR/

ls -al /boot/efi/*

 $NOTIFY --urgency=critical 'Copied kernel to UEFI boot dir'



printf "Cleaning up the build directory .....\n\n"

(rm -rf $build_dir) &

spinner "$!" "Cleaning up...wait"

$NOTIFY --urgency=critical 'Kernel Update finished'


}


which_kernel() {
printf "\n\n Which kernel would be your base? Stable or Mainline or Longterm? [S/M/L]: %s"
read response

if [[ $response == "S" ]];then
#Get the stable kernel from kernel.org
kernel=$(curl -s https://www.kernel.org/ | grep -A1 'stable:' | grep -oP '(?<=strong>).*(?=</strong.*)' | grep 6.7)
elif [[ $response == "M" ]];then
#Get the mainline kernel from kernel.org
kernel=$(curl -s https://www.kernel.org/ | grep -A1 'mainline:' | grep -oP '(?<=strong>).*(?=</strong.*)')
elif [[ $response == "L" ]];then
#Get the longterm kernel from kernel.org
kernel=$(curl -s https://www.kernel.org/ | grep -A1 'longterm:' | grep -oP '(?<=strong>).*(?=</strong.*)')
fi
}

slackware_kernel_build
