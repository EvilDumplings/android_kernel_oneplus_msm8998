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


# # # SET GLOBAL VARIABLES # # #

export ARCH=arm64;
export CROSS_COMPILE=$BUILD_CROSS_COMPILE/bin/aarch64-linux-android-;


# # # VERIFY TOOLCHAIN PRESENCE # # #

FUNC_VERIFY_TOOLCHAIN()
{
  if [ ! -d "$BUILD_CROSS_COMPILE" ]; then
    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 $BUILD_CROSS_COMPILE;
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
    git clone https://github.com/EvilDumplings/AnyKernel2.git $BUILD_ZIP_DIR;
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
  rm -rf $KERNEL_MODULES/*;
  rm -rf $PRODUCT_OUT/*.zip;
}


# # # BUILD CONFIG AND KERNEL # # #

FUNC_BUILD()
{
  mkdir -p $BUILD_KERNEL_OUT_DIR;

  make O=$BUILD_KERNEL_OUT_DIR primal_oneplus5_defconfig;
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
  cd $BUILD_ZIP_DIR;
  zip -r9 $PRODUCT_OUT/primal-oneplus5-custom-v1.0.0.zip * \
      -x patch/* ramdisk/* *.placeholder
  cd $BUILD_KERNEL_DIR;
}

# MAIN FUNCTION
(
  FUNC_VERIFY_TOOLCHAIN;
  FUNC_VERIFY_TEMPLATE;
  FUNC_CLEAN_OUTPUT;
  FUNC_BUILD;
  FUNC_STRIP_MODULES;
  FUNC_SIGN_MODULES;
  FUNC_COPY_KERNEL;
  FUNC_COPY_MODULES;
  FUNC_BUILD_ZIP;
)
