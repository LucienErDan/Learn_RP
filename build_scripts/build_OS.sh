#!/bin/bash

PATH_XILINX_SDK=/opt/Xilinx/SDK/2017.2
PATH_XILINX_VIVADO=/opt/Xilinx/Vivado/2017.2
RP_UBUNTU=redpitaya_ubuntu_13-14-23_25-sep-2017.tar.gz
SCHROOT_CONF_PATH=/etc/schroot/chroot.d/red-pitaya-ubuntu.conf

#脚本函数
function print_ok(){
    echo -e "\033[92m[OK]\e[0m"
}

function print_fail(){
    echo -e "\033[91m[FAIL]\e[0m"
}

echo Start build process...
# Check Xilinx vivado path


echo
echo "Setup development packages"

#检查工具链是否装上，-y是yes的意思，表示没装上就会安装
# generic dependencies
sudo apt-get install make curl xz-utils -y
# U-Boot build dependencies
sudo apt-get install libssl-dev device-tree-compiler u-boot-tools -y
# secure chroot
sudo apt-get install schroot -y
# QEMU
sudo apt-get install qemu qemu-user qemu-user-static -y
# 32 bit libraries
sudo apt-get install lib32z1 lib32ncurses5 libbz2-1.0:i386 lib32stdc++6 -y

sudo apt-get install device-tree-compiler -y

sleep 1
echo
echo -n "Complete development packages "
print_ok

sleep 1

echo
echo "Setup Meson python packages"
#介绍meson的链接
#https://blog.csdn.net/sam2009944096/article/details/106842867
sudo apt-get install python3 python3-pip -y
sudo pip3 install --upgrade pip -y
sudo pip3 install meson -y
sudo apt-get install ninja-build -y

sleep 1
echo
echo -n "Complete Meson python packages "
print_ok

sleep 1
echo
sudo ln -s /usr/bin/make /usr/bin/gmake
echo

sleep 1

# -d if dir exist，expression is true
if [[ -d "$PATH_XILINX_SDK" ]]
then
    echo -n "$PATH_XILINX_SDK exists on your filesystem. "
    print_ok
else 
    echo -n "Can't find $PATH_XILINX_SDK on your PC. "
    print_fail
    echo "Check the correct path to Xilinx SDK"
    exit 1
fi
sleep 1
if [[ -d "$PATH_XILINX_VIVADO" ]]
then
    echo -n "$PATH_XILINX_VIVADO exists on your filesystem. "
    print_ok
else 
    echo -n "Can't find $PATH_XILINX_VIVADO on your PC. "
    print_fail
    echo "Check the correct path to Xilinx Vivado"
    exit 1
fi

sleep 1

cd ..

export DL=${PWD}/tmp/DL

mkdir -p $DL
echo -n "Created directory for download. "
if [[ -d "$PATH_XILINX_SDK" ]]
then
print_ok
else
print_fail
exit 1
fi

#？？？？？？？？？？？？？？？？？？下载这个干嘛,而且还改成了root所own
echo -n "Download redpitaya ubuntu OS. "
cd $DL

#   RP_UBUNTU=redpitaya_ubuntu_13-14-23_25-sep-2017.tar.gz
wget -N http://downloads.redpitaya.com/downloads/$RP_UBUNTU
#   chown 用户:组
sudo chown root:root redpitaya_ubuntu_13-14-23_25-sep-2017.tar.gz
sudo chmod 664 redpitaya_ubuntu_13-14-23_25-sep-2017.tar.gz

echo -n "Check redpitaya ubuntu OS. "
if [[ -f "$RP_UBUNTU" ]]#-f检查是否为常规文件
then
print_ok
else
print_fail
exit 1
fi

#改变目录到前两级
cd ../..

#   SCHROOT_CONF_PATH=/etc/schroot/chroot.d/red-pitaya-ubuntu.conf
if [[ -f "$SCHROOT_CONF_PATH" ]]
then
echo "File $SCHROOT_CONF_PATH is exists"
sudo rm -f $SCHROOT_CONF_PATH
echo "File $SCHROOT_CONF_PATH is deleted"
fi

sleep 1
echo  "Write new configuration"
echo 
echo  "[red-pitaya-ubuntu]"      | sudo tee -a $SCHROOT_CONF_PATH #tee从读取标准输入数据并输出到文件 -a：append
echo  "description=Red pitaya"   | sudo tee -a $SCHROOT_CONF_PATH
echo  "type=file"                | sudo tee -a $SCHROOT_CONF_PATH
echo  "file=$DL/$RP_UBUNTU"      | sudo tee -a $SCHROOT_CONF_PATH
echo  "users=root"               | sudo tee -a $SCHROOT_CONF_PATH
echo  "root-users=root"          | sudo tee -a $SCHROOT_CONF_PATH
echo  "root-groups=root"         | sudo tee -a $SCHROOT_CONF_PATH
echo  "personality=linux"        | sudo tee -a $SCHROOT_CONF_PATH
echo  "preserve-enviroment=true" | sudo tee -a $SCHROOT_CONF_PATH

#$? 判断上一个命令或者函数的返回值
if [[ $? = 0 ]] 
then
echo 
echo -n "Complete write new configuration "
print_ok
echo 
else 
echo -n "Complete write new configuration "
print_fail
exit 1
fi

set -e #如果任何语句的执行结果不是true（命令的执行结果为0）则应该退出。
pwd
chmod +x ./settings.sh
./settings.sh
echo -n "Call settings.sh "
print_ok

#?????????????这里的变量有何用
export ENABLE_LICENSING=0
export CROSS_COMPILE=arm-linux-gnueabihf-
export ARCH=arm
export PATH=$PATH:$PATH_XILINX_VIVADO/bin
export PATH=$PATH:$PATH_XILINX_SDK/bin
export PATH=$PATH:$PATH_XILINX_SDK/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/
ENABLE_PRODUCTION_TEST=0
GIT_COMMIT_SHORT=`git rev-parse --short HEAD`

make -f Makefile.x86  MODEL=$MODEL
schroot -c red-pitaya-ubuntu <<- EOL_CHROOT
make -f Makefile CROSS_COMPILE="" REVISION=$GIT_COMMIT_SHORT MODEL=$MODEL ENABLE_PRODUCTION_TEST=$ENABLE_PRODUCTION_TEST
EOL_CHROOT
make -f Makefile.x86 install MODEL=$MODEL
make -f Makefile.x86 zip MODEL=$MODEL
