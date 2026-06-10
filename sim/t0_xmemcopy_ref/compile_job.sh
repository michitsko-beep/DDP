#!/bin/bash
shopt -s expand_aliases
source $K5_XBOX_ENV/setup/k5_rc3_setup.sh
export K5_APP_SHARED_LIB="$K5_ENV/sw/libs/null_shared_lib"
cd $K5_SW_APPS/FFT_conv 
rm -f build/* 
$K5_ENV/sw/sw_utils/comp_app_local_rc3.sh FFT_conv _SPMT_  "-D_XBOX_ -I$K5_XBOX_ENV/sw/xbox_libs" _MAX10_FPGA_ 24576
cd -
