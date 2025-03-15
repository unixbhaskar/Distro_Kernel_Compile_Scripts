#!/usr/bin/env bash
# This script will build debian kernel package from the upstream stable kernel

get_elapsed_time="/usr/bin/time -f"
build_dir=/home/bhaskar/git-linux/debian_kernel_build
existing_config_file="/boot/config-$(uname -r)"
custom_kernel_package_holder=/home/bhaskar/git-linux/

debian_kernel_build() {

# Check if build dir exists, if not then pull and build

if [ ! -d "$build_dir" ];then
	echo Gosh! It will take hell lot of time to clone the repo ...take a break ...
	echo
	$get_elapsed_time "\n\n\tTime Elapsed: %E\n\n" git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$build_dir"
 else
	 echo Dir exists!! Getting into the git repo ...

         cd $build_dir || exit 1
fi

echo Cleaning previous stale stuff and pull new stuffs in

 cd "$build_dir" || exit 1

 git reset --hard

 git clean -dfx

 git pull

# echo Getting the build dependencies for kernel build :
# echo

# apt install devscripts
# /usr/bin/mk-build-deps

#Clean the dir
make clean && make mrproper

#Copying existing/running kernel config
cp $existing_config_file .config
ls -al .config

#Disable this option to shorten the compile time
scripts/config --disable DEBUG_KERNEL
grep DEBUG_KERNEL .config

#Disable this option to shorten the compile time
scripts/config --disable DEBUG_INFO
grep DEBUG_INFO .config

# Set local hostname added to the kernel name
scripts/config --set-str LOCALVERSION "-$(hostname)"

#This is needed ,otherwise it won't allow you to build
scripts/config --disable system_trusted_keys
grep CONFIG_SYSTEM_TRUSTED_KEYS .config

# Make config with all the currently loaded modules
 yes '' | make localmodconfig

#Make sure the flags symbols are set correctly with an updated value
# make  ARCH=x86_64 olddefconfig

# Now build it
$get_elapsed_time "\n\n\tTime Elapsed: %E\n\n" make ARCH=x86_64 V=1 -j$(getconf _NPROCESSORS_ONLN) deb-pkg


 printf "\n\n\n Install the generated packages aka kernel,headers,modules et al \n\n\n"

 cd ..

 dpkg -i *.deb
 
# Scanning the freshly created packages  

printf "\n\n\n\n Now collecting the packages in a file to feed the package management system\n\n\n"

>Debian_Custom_Kernel_Packages

dpkg-scanpackages "$custom_kernel_package_holder" > Debian_Custom_Kernel_Packages

# Make the package management system aware of the packages 

 printf "\n\n\n Merging with the local package management system \n\n\n"
 dpkg --merge-avail Debian_Custom_Kernel_Packages 


# if [ $? -eq 0 ];then

#      find /boot -maxdepth 1 -name "vmlinuz-*" -type f -ls

#      printf "\nGive the kernel number for initramfs generation: %s"
#      read -r ramfs

#      /usr/bin/dracut --hostonly --kver "$ramfs" 

#     echo "Kernel update process done"
# else
# 	echo "Nope, the package install have trouble."
# fi


}
debian_kernel_build
