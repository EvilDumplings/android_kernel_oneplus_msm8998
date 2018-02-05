#!/bin/bash

# # # SET LOCAL VARIABLES # # #

BUILD_KERNEL_DIR=`pwd`;
BUILD_ROOT_DIR=$(dirname $BUILD_KERNEL_DIR);
PRODUCT_OUT=$BUILD_ROOT_DIR/out;
BUILD_KERNEL_OUT_DIR=$PRODUCT_OUT/KERNEL_OBJ;
BUILD_ZIP_DIR=$PRODUCT_OUT/AnyKernel2;

BUILD_CROSS_COMPILE=$BUILD_ROOT_DIR/aarch64-linux-android-4.9;

KERNEL_IMG=$BUILD_ZIP_DIR/Image.gz-dtb;
KERNEL_MODULES=$BUILD_ZIP_DIR/modules/system/vendor/lib/modules;

BUILD_JOB_NUMBER=`nproc --all`;


# # # SET KERNEL ID # # #

PRODUCT_NAME=primal
PRODUCT_NAME_DISPLAY=Primal
PRODUCT_DEVICE=oneplus5
PRODUCT_PLATFORM=custom
PRODUCT_VERSION=1.0.0


# # # SET GLOBAL VARIABLES # # #

export ARCH=arm64;
export CROSS_COMPILE=$BUILD_CROSS_COMPILE/bin/aarch64-linux-android-;

export LOCALVERSION=-$PRODUCT_NAME_DISPLAY-$PRODUCT_VERSION


# # # VERIFY TOOLCHAIN PRESENCE # # #

FUNC_VERIFY_TOOLCHAIN()
{
  if [ ! -d "$BUILD_CROSS_COMPILE" ]; then
    git clone https://source.codeaurora.org/quic/la/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 $BUILD_CROSS_COMPILE \
        -b android-framework.lnx.2.9.1.r2-rel;
  else
    cd $BUILD_CROSS_COMPILE;
    git pull;
    cd $BUILD_KERNEL_DIR;
  fi;
}


# # # VERIFY ZIP TEMPLATE PRESENCE # # #

FUNC_VERIFY_TEMPLATE()
{
  if [ ! -d "$BUILD_ZIP_DIR" ]; then
    git clone https://github.com/EvilDumplings/AnyKernel2.git $BUILD_ZIP_DIR \
        -b oreo-mr1;
  else
    cd $BUILD_ZIP_DIR;
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
  rm -rf $PRODUCT_OUT/*.zip;
}


# # # BUILD CONFIG AND KERNEL # # #

FUNC_BUILD()
{
  mkdir -p $BUILD_KERNEL_OUT_DIR;

  make O=$BUILD_KERNEL_OUT_DIR ${PRODUCT_NAME}_${PRODUCT_DEVICE}_defconfig;
  make O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER || exit -1;
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

FUNC_COPY_KERNEL()
{
  cp $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/Image.gz-dtb $KERNEL_IMG;
}
FUNC_COPY_MODULES()
{
  find $BUILD_KERNEL_OUT_DIR \
      -name "*.ko" \
      -exec cp {} $KERNEL_MODULES \;
}


# # # BUILD ZIP # # #

FUNC_BUILD_ZIP()
{
  BUILD_ZIP_IGNORED="patch/* ramdisk/* *.placeholder";
  if [ "$PRODUCT_PLATFORM" == "custom" ]; then
    BUILD_ZIP_IGNORED="modules/* $BUILD_ZIP_IGNORED";
  fi;
  
  cd $BUILD_ZIP_DIR;
  zip -r9 $PRODUCT_OUT/$PRODUCT_NAME-$PRODUCT_DEVICE-$PRODUCT_PLATFORM-v$PRODUCT_VERSION.zip * \
      -x $BUILD_ZIP_IGNORED
  cd $BUILD_KERNEL_DIR;
}

# MAIN FUNCTION
(
  FUNC_VERIFY_TOOLCHAIN;
  FUNC_VERIFY_TEMPLATE;
  FUNC_CLEAN_OUTPUT;
  FUNC_BUILD;
  if [ "$PRODUCT_PLATFORM" == "oos" ]; then
    FUNC_STRIP_MODULES;
    FUNC_SIGN_MODULES;
  fi;
  FUNC_COPY_KERNEL;
  if [ "$PRODUCT_PLATFORM" == "oos" ]; then
    FUNC_COPY_MODULES;
  fi;
  FUNC_BUILD_ZIP;
)
