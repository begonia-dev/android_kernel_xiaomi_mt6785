#!/bin/sh

# Defined path
MainPath="$(pwd)"
trb="$(pwd)/../trb"
Any="$(pwd)/../AnyKernel3"

# Make flashable zip
MakeZip() {
        cd $Any
        git reset --hard
        git checkout master
        git fetch origin master
        git reset --hard origin/master
    cp -af $MainPath/out/arch/arm64/boot/Image.gz-dtb $Any
    sed -i "s/kernel.string=.*/kernel.string=$KERNEL_NAME-$HeadCommit test by $KBUILD_BUILD_USER/g" anykernel.sh
    zip -r9 $MainPath/"[$Compiler][R-OSS]-$ZIP_KERNEL_VERSION-$KERNEL_NAME-$TIME.zip" * -x .git README.md *placeholder
    cd $MainPath
}

# Clone compiler
if [ ! -d $trb ]; then
    git clone --depth=1 https://gitlab.com/varunhardgamer/trb_clang.git -b 14 $TRB
fi

# Defined config
HeadCommit="$(git log --pretty=format:'%h' -1)"
export ARCH="arm64"
export SUBARCH="arm64"
export KBUILD_BUILD_USER="AbdulWahid"
export KBUILD_BUILD_HOST="PC"
Defconfig="begonia_user_defconfig"
KERNEL_NAME=$(cat "$MainPath/arch/arm64/configs/$Defconfig" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
ZIP_KERNEL_VERSION="4.14.$(cat "$MainPath/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')$(cat "$(pwd)/Makefile" | grep "EXTRAVERSION =" | sed 's/EXTRAVERSION = *//g')"
TIME=$(date +"%m%d%H%M")

# Start building
Compiler=TRB
MAKE="./makeparallel"
rm -rf out
BUILD_START=$(date +"%s")

make  -j$(nproc --all)  O=out ARCH=arm64 SUBARCH=arm64 $Defconfig
exec 2> >(tee -a out/error.log >&2)

make  -j$(nproc --all)  O=out \
                        PATH="$trb/bin:/usr/bin:$PATH" \
                        LD_LIBRARY_PATH="$trb/lib:$LD_LIBRABRY_PATH" \
                        CC=clang \
                        AS=llvm-as \
                        NM=llvm-nm \
                        OBJCOPY=llvm-objcopy \
                        OBJDUMP=llvm-objdump \
                        STRIP=llvm-strip \
                        LD=ld.lld \
                        CROSS_COMPILE=aarch64-linux-gnu- \
                        CROSS_COMPILE_ARM32=arm-linux-gnueabi-

if [ -e $MainPath/out/arch/arm64/boot/Image.gz-dtb ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    MakeZip
    echo "Build success in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    echo "Build fail in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
