#!/usr/bin/env bash

export  BOLD="\e[1m"
export  NORMAL="\e[0m"
export	RED="\e[31m"
export	GREEN="\e[32m"
export	YELLOW="\e[33m"
export  BLUE="\e[94m"
export  CYAN="\e[36m"

export WORKSPACE=$PWD
export PATH_OUT="${WORKSPACE}/output"

export ARM_TOOLCHAIN_ELF="gcc-arm-10.2-2020.11-x86_64-aarch64-none-elf"
export UEFI_PROJECT="Merak"
export GCC5_AARCH64_PREFIX="${WORKSPACE}/tools/gcc/${ARM_TOOLCHAIN_ELF}/bin/aarch64-none-elf-"
export IASL_PREFIX="${WORKSPACE}/tools/acpica/generate/unix/bin/"
export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi


exec_build_uefi() {

if [ ! -e $WORKSPACE/edk2/MdeModulePkg/Library/BrotliCustomDecompressLib/brotli/.git ]; then
	echo "Need update edk2 submodule!"
	cd $WORKSPACE/edk2
	git submodule init
	git config --list|grep submodule.*url=|sed -e 's#^\(.*url\)=https://github.com/\(.*\)$#git config \1 ssh://git@gitmirror.cixcomputing.com/github_mirror/\2##g'|while read c;do $c;done
	git submodule update --init
fi

cd $WORKSPACE/edk2-platforms
local COMMIT_HASH=`git rev-parse --short=12 HEAD`

cd $WORKSPACE

if [ ! -e $WORKSPACE/Source/C/bin ]; then
	echo "Need build edk2 basetool!"
	make -C edk2/BaseTools
fi

if [ ! -e $WORKSPACE/tools/acpica/generate/unix/bin ]; then
	echo "Need build acpi tool!"
	make -C tools/acpica
fi

source $WORKSPACE/edk2/edksetup.sh --reconfig

rm -rf ${WORKSPACE}/Build

local BUILD_DATE=`date +%VM%y%m%d%H%M%SN`
local UEFI_TARGET=RELEASE
local BOARD=evb
local UEFI_DSC_FILE="Platform/CIX/Sky1/${UEFI_PROJECT}/${UEFI_PROJECT}.dsc"
build -a AARCH64 -t GCC5 -p $UEFI_DSC_FILE -b $UEFI_TARGET -D BOARD_NAME=$BOARD -D BUILD_DATE=$BUILD_DATE -D COMMIT_HASH=$COMMIT_HASH -D SMP_ENABLE=1 -D ACPI_BOOT_ENABLE=1

cp Build/${UEFI_PROJECT}/${UEFI_TARGET}_GCC5/FV/SKY1_BL33_UEFI.fd ${PATH_OUT}

}

build_memcfg(){
    echo -e "BUILD MEMCFG $1 Started."
    local memcfg_dir="${WORKSPACE}/edk2-non-osi/Platform/CIX/Sky1/PackageTool/memory_config_tool_common"
    local PATH_FIRMARES="${PATH_OUT}/Firmwares"
    local memcfg_file="memory_config.bin"
    local MEM_CFG_MEMFREQ="1600"

    if [ "$1" == "3200" ]; then
        MEM_CFG_MEMFREQ="1600"
    elif [ "$1" == "5500" ]; then
        MEM_CFG_MEMFREQ="2750"
    elif [ "$1" == "6400" ]; then
        MEM_CFG_MEMFREQ="3200"
    fi

    cd $memcfg_dir

    #compile and generate the memory config with the param: $MEM_CONF_FREQ and $MEM_CONF_CH
    make -e CFLAG:="-DMEM_CFG_MEMFREQ=${MEM_CFG_MEMFREQ} -DMEM_CFG_CHMASK=15" || exit 1

    cp $memcfg_dir/$memcfg_file $PATH_FIRMARES

    cd -
    echo -e "${GREEN}BUILD MEMCFG[$1] Success.${NORMAL}"
}


exec_cix_mkimage() {
    export PATH_PACKAGE_TOOL="${WORKSPACE}/edk2-non-osi/Platform/CIX/Sky1/PackageTool"
    local PATH_FIRMARES="${PATH_OUT}/Firmwares"
    local PATH_KEYS="${PATH_OUT}/Keys"
    local PATH_PROJECT_FIRMARE="${WORKSPACE}/edk2-platforms/Platform/CIX/Sky1/${UEFI_PROJECT}"

    # copy require files to output
    cp -r "${PATH_PACKAGE_TOOL}/Firmwares/" "${PATH_OUT}"

    cp -r "${PATH_PACKAGE_TOOL}/Keys/" "${PATH_OUT}"

    # build memory config
    build_memcfg 5500

    # update project specific ec firmware
    if [[ -e "${PATH_PROJECT_FIRMARE}/ec_firmware.bin" ]]; then
        echo "found project specific ec firmware ${PATH_PROJECT_FIRMARE}/ec_firmware.bin"
        cp "${PATH_PROJECT_FIRMARE}/ec_firmware.bin" "${PATH_FIRMARES}"
    fi

    # check bootloader1 image
    if [[ ! -e "${PATH_FIRMARES}/bootloader1.img" ]]; then
        echo "ERROR: no file ${PATH_FIRMARES}/bootloader1.img"
        exit 1
    fi

    # Generate bootloader2 image
    cd "${PATH_OUT}"

    "${PATH_PACKAGE_TOOL}/cix_image_tool.sh" -p -K Keys -T rsa3072 --bf31 "${PATH_FIRMARES}/tf-a.bin" --bf32 "${PATH_FIRMARES}/tee.bin" --bf33 "${PATH_OUT}/SKY1_BL33_UEFI.fd" -o "${PATH_FIRMARES}/bootloader2.img"

    cd -
    if [[ ! -e "${PATH_FIRMARES}/bootloader2.img" ]]; then
        echo "ERROR: no file ${PATH_FIRMARES}/bootloader2.img"
        exit 1
    fi

    # Generate spi flash image
    cd "${PATH_OUT}"

    echo "${PATH_PACKAGE_TOOL}/cix_package_tool" -c "${PATH_PACKAGE_TOOL}/cix_spi_flash_config.json" -o "${PATH_OUT}/cix_flash_all.bin"
    "${PATH_PACKAGE_TOOL}/cix_package_tool" -c "${PATH_PACKAGE_TOOL}/cix_spi_flash_config.json" -o "${PATH_OUT}/cix_flash_all.bin"

    cd -

    echo -e "${GREEN}Generate ${PATH_OUT}/cix_flash_all.bin successful!${NORMAL}"

}

if [[ ! -e "${WORKSPACE}/edk2-non-osi/Platform/CIX/Sky1/PackageTool/build_and_package.sh" ]]; then
    echo "Your work path ${WORKSPACE} not contain edk2-non-osi for CIX!"
    exit 1
fi

if [[ -e "${PATH_OUT}" ]]; then
    rm -rf "${PATH_OUT}"
fi

if [[ ! -e "${PATH_OUT}" ]]; then
    mkdir -p "${PATH_OUT}"
fi

if [ ! -z "$1" ]; then
    UEFI_PROJECT="$1"
fi

echo "Build UEFI Project $UEFI_PROJECT"

exec_build_uefi
exec_cix_mkimage
