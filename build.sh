#!/bin/bash

# # # SET LOCAL VARIABLES # # #

BUILD_KERNEL_DIR=`pwd`;
BUILD_ROOT_DIR=$(dirname $BUILD_KERNEL_DIR);
PRODUCT_OUT=$BUILD_ROOT_DIR/out;
BUILD_KERNEL_OUT_DIR=$PRODUCT_OUT/KERNEL_OBJ;

BUILD_CROSS_COMPILE=$BUILD_ROOT_DIR/aarch64-linux-android-4.9;

KERNEL_IMG=$PRODUCT_OUT/Image.gz-dtb;
KERNEL_MODULES=$PRODUCT_OUT/modules/system/vendor/lib/modules;

BUILD_JOB_NUMBER=`nproc --all`;


# # # SET GLOBAL VARIABLES # # #

export ARCH=arm64;
export CROSS_COMPILE=$BUILD_CROSS_COMPILE/bin/aarch64-linux-android-;


# # # VERIFY TOOLCHAIN PRESENCE # # #

if [ ! -d "$BUILD_CROSS_COMPILE" ]; then
  git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 $BUILD_CROSS_COMPILE;
else
  cd $BUILD_CROSS_COMPILE;
  git pull;
  cd $BUILD_KERNEL_DIR;
fi;


# # # CLEAN BUILD OUTPUT # # #

rm -rf $BUILD_KERNEL_OUT_DIR;
rm -f $KERNEL_IMG;
rm -rf $KERNEL_MODULES;


# # # BUILD CONFIG AND KERNEL # # #

mkdir -p $BUILD_KERNEL_OUT_DIR;

make O=$BUILD_KERNEL_OUT_DIR primal_oneplus5_defconfig;
make O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER;


# # # STRIP AND RESIGN MODULES # # #

find $BUILD_KERNEL_OUT_DIR \
    -name "*.ko" \
    -exec ${CROSS_COMPILE}strip --strip-unneeded {} \;
find $BUILD_KERNEL_OUT_DIR \
    -name "*.ko"  \
    -exec $BUILD_KERNEL_OUT_DIR/scripts/sign-file sha512 $BUILD_KERNEL_OUT_DIR/certs/signing_key.pem $BUILD_KERNEL_OUT_DIR/certs/signing_key.x509 {} \;


# # # COPY BUILD OUTPUT # # #

mkdir -p $KERNEL_MODULES;

cp $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/Image.gz-dtb $KERNEL_IMG;
find $BUILD_KERNEL_OUT_DIR \
    -name "*.ko" \
    -exec cp {} $KERNEL_MODULES \;
