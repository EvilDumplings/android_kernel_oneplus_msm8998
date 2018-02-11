#!/bin/bash
#
# Android Kernel Build Script v2.0
#
# Copyright (C) 2018 Michele Beccalossi <beccalossi.michele@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# # # SET KERNEL ID # # #

PRODUCT_NAME=primal;
PRODUCT_NAME_DISPLAY=Primal_Kernel;
PRODUCT_DEVICE=oneplus5;
PRODUCT_PLATFORM=custom;
PRODUCT_VERSION=1.2.0;


# # # SET TOOLS PARAMETERS # # #

CROSS_COMPILE_NAME=aarch64-linux-android-4.9;
CROSS_COMPILE_SUFFIX=aarch64-linux-android-;
CROSS_COMPILE_HAS_GIT=true;
CROSS_COMPILE_GIT=https://source.codeaurora.org/quic/la/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9;
CROSS_COMPILE_BRANCH=android-framework.lnx.2.9.1.r2-rel;

USE_CCACHE=true;

ZIP_DIR_GIT=https://github.com/EvilDumplings/AnyKernel2.git;
ZIP_DIR_BRANCH=oreo-mr1;


# # # SET LOCAL VARIABLES # # #

BUILD_KERNEL_DIR=$(pwd);
BUILD_KERNEL_DIR_NAME=$(basename $BUILD_KERNEL_DIR);
BUILD_ROOT_DIR=$(dirname $BUILD_KERNEL_DIR);
PRODUCT_OUT=$BUILD_ROOT_DIR/${BUILD_KERNEL_DIR_NAME}_out;
BUILD_KERNEL_OUT_DIR=$PRODUCT_OUT/KERNEL_OBJ;
BUILD_ZIP_DIR=$PRODUCT_OUT/AnyKernel2;

BUILD_CROSS_COMPILE=$BUILD_ROOT_DIR/$CROSS_COMPILE_NAME;
KERNEL_DEFCONFIG=${PRODUCT_NAME}_${PRODUCT_DEVICE}_defconfig;

KERNEL_IMG=$BUILD_ZIP_DIR/Image.gz-dtb;
KERNEL_MODULES=$BUILD_ZIP_DIR/modules/system/vendor/lib/modules;

BUILD_JOB_NUMBER=$(nproc --all);
HOST_ARCH=$(uname -m);


# # # SET GLOBAL VARIABLES # # #

export ARCH=arm64;

if [ "$HOST_ARCH" == "x86_64" ]; then
  export CROSS_COMPILE=$BUILD_CROSS_COMPILE/bin/$CROSS_COMPILE_SUFFIX;
fi;

export LOCALVERSION="-${PRODUCT_NAME_DISPLAY}_v${PRODUCT_VERSION}";


# # # VERIFY PRODUCT OUTPUT FOLDER EXISTENCE # # #
if [ ! -d "$PRODUCT_OUT" ]; then
  mkdir $PRODUCT_OUT;
fi;

# # # VERIFY TOOLCHAIN PRESENCE # # #

FUNC_VERIFY_TOOLCHAIN()
{
  if [ ! -d "$BUILD_CROSS_COMPILE" ]; then
    git clone $CROSS_COMPILE_GIT $BUILD_CROSS_COMPILE \
        -b $CROSS_COMPILE_BRANCH;
  else
    cd $BUILD_CROSS_COMPILE;
    git checkout $CROSS_COMPILE_BRANCH;
    git pull;
    cd $BUILD_KERNEL_DIR;
  fi;
}


# # # VERIFY ZIP TEMPLATE PRESENCE # # #

FUNC_VERIFY_TEMPLATE()
{
  if [ ! -d "$BUILD_ZIP_DIR" ]; then
    git clone $ZIP_DIR_GIT $BUILD_ZIP_DIR \
        -b $ZIP_DIR_BRANCH;
  else
    cd $BUILD_ZIP_DIR;
    git checkout $ZIP_DIR_BRANCH;
    git pull;
    cd $BUILD_KERNEL_DIR;
  fi;
}


# # # CLEAN BUILD OUTPUT # # #

FUNC_CLEAN_OUTPUT()
{
  rm -rf $BUILD_KERNEL_OUT_DIR;
  rm -f $KERNEL_IMG;
  if [ "$PRODUCT_PLATFORM" == "oos" ]; then
    rm -rf $KERNEL_MODULES/*;
  fi;
  rm -f $PRODUCT_OUT/*.zip;
}


# # # BUILD CONFIG AND KERNEL # # #

FUNC_BUILD()
{
  mkdir $BUILD_KERNEL_OUT_DIR;

  make O=$BUILD_KERNEL_OUT_DIR $KERNEL_DEFCONFIG;
  cp -f $BUILD_KERNEL_OUT_DIR/.config $BUILD_KERNEL_DIR/arch/arm64/configs/$KERNEL_DEFCONFIG;

  if [ "$USE_CCACHE" == true ]; then
    make O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER \
    CC="ccache ${CROSS_COMPILE}gcc" CPP="ccache ${CROSS_COMPILE}gcc -E" || exit 1;
  else
    make O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER || exit 1;
  fi;
}


# # # STRIP AND RESIGN MODULES # # #

FUNC_STRIP_MODULES()
{
  find $BUILD_KERNEL_OUT_DIR \
      -name "*.ko" \
      -exec ${CROSS_COMPILE}strip --strip-unneeded {} \;
}

FUNC_SIGN_MODULES()
{
  find $BUILD_KERNEL_OUT_DIR \
      -name "*.ko"  \
      -exec $BUILD_KERNEL_OUT_DIR/scripts/sign-file sha512 $BUILD_KERNEL_OUT_DIR/certs/signing_key.pem $BUILD_KERNEL_OUT_DIR/certs/signing_key.x509 {} \;
}


# # # COPY BUILD OUTPUT # # #

FUNC_COPY_MODULES()
{
  find $BUILD_KERNEL_OUT_DIR \
      -name "*.ko" \
      -exec cp {} $KERNEL_MODULES \;
}

FUNC_COPY_KERNEL()
{
  cp $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/Image.gz-dtb $KERNEL_IMG;
}


# # # BUILD ZIP # # #

FUNC_BUILD_ZIP()
{
  cd $BUILD_ZIP_DIR;
  if [ "$PRODUCT_PLATFORM" == "oos" ]; then
    zip -r9 $PRODUCT_OUT/$PRODUCT_NAME-$PRODUCT_DEVICE-$PRODUCT_PLATFORM-v$PRODUCT_VERSION.zip * \
        -x patch/\* ramdisk/\*;
  else
    zip -r9 $PRODUCT_OUT/$PRODUCT_NAME-$PRODUCT_DEVICE-$PRODUCT_PLATFORM-v$PRODUCT_VERSION.zip * \
        -x modules/\* patch/\* ramdisk/\*;
  fi;
  cd $BUILD_KERNEL_DIR;
}

# MAIN FUNCTION
rm -f $PRODUCT_OUT/build.log;
(
  if [ "$HOST_ARCH" == "x86_64" ] && [ "$CROSS_COMPILE_HAS_GIT" == true ]; then
    FUNC_VERIFY_TOOLCHAIN;
  fi;
  FUNC_VERIFY_TEMPLATE;
  FUNC_CLEAN_OUTPUT;
  FUNC_BUILD;
  if [ "$PRODUCT_PLATFORM" == "oos" ]; then
    FUNC_STRIP_MODULES;
    FUNC_SIGN_MODULES;
    FUNC_COPY_MODULES;
  fi;
  FUNC_COPY_KERNEL;
  FUNC_BUILD_ZIP;
) 2>&1 | tee $PRODUCT_OUT/build.log;
