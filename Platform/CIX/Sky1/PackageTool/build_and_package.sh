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
export PATH_OUT_PR="${WORKSPACE}/output/pr"
export PATH_OUT_PR2="${WORKSPACE}/output/pr2"

export ARM_TOOLCHAIN_ELF="gcc-arm-10.2-2020.11-x86_64-aarch64-none-elf"
if [ "$(uname -m)" = "aarch64" ]; then
  export ARM_TOOLCHAIN_ELF="gcc-arm-10.3-2021.07-aarch64-aarch64-none-elf"
fi
export UEFI_PROJECT="Merak"
export UEFI_PROJECT_FOLDER="edk2-platforms"
export UEFI_PROJECT_PATH="Platform/CIX/Sky1"
export GCC5_AARCH64_PREFIX="${WORKSPACE}/tools/gcc/${ARM_TOOLCHAIN_ELF}/bin/aarch64-none-elf-"
export IASL_PREFIX="${WORKSPACE}/tools/acpica/generate/unix/bin/"
export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi
export OS_SUPPORT_TYPE="common"
export FASTBOOT_LOAD_TYPE="disable"

exec_blankfile() {
    if [[ -e $1 ]]; then
        rm -rf $1
    fi
	for ((i=0;i<$2;i++))
	do
		echo -e -n "\xFF" >> $1
	done
}

exec_build_uefi() {

if [ ! -e $WORKSPACE/edk2/MdeModulePkg/Library/BrotliCustomDecompressLib/brotli/.git ]; then
	echo "Need update edk2 submodule!"
	cd $WORKSPACE/edk2
    if [ "${NETWORK}" == "internal" ];then
	    git submodule init
	    git config --list|grep submodule.*url=| grep 'github.com' | sed -e 's#^\(.*url\)=https://github.com/\(.*\)$#git config \1 ssh://git@gitmirror.cixcomputing.com/github_mirror/\2##g'|while read c;do $c;done
    fi
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
local UEFI_DSC_FILE="${UEFI_PROJECT_PATH}/${UEFI_PROJECT}/${UEFI_PROJECT}.dsc"
local VARIABLE_TYPE=SPI
local STMM_SUPPORT=TRUE

build -a AARCH64 -t GCC5 -p $UEFI_DSC_FILE -b $UEFI_TARGET -D BOARD_NAME=$BOARD -D BUILD_DATE=$BUILD_DATE -D COMMIT_HASH=$COMMIT_HASH -D SMP_ENABLE=1 -D ACPI_BOOT_ENABLE=1 -D FASTBOOT_LOAD=$FASTBOOT_LOAD_TYPE -D VARIABLE_TYPE=$VARIABLE_TYPE -D STANDARD_MM=$STMM_SUPPORT -D SYSTEM_LOADER=$OS_SUPPORT_TYPE

cp Build/${UEFI_PROJECT}/${UEFI_TARGET}_GCC5/FV/SKY1_BL33_UEFI.fd ${PATH_OUT}

if [ "$OS_SUPPORT_TYPE" == "android" ]; then
    cp edk2-non-osi/Platform/CIX/Sky1/Application/LinuxLoader/LinuxLoader.efi edk2-platforms/Platform/CIX/Sky1/Sky1ABL/
    cd edk2-platforms/Platform/CIX/Sky1/Sky1ABL
    ./GenAblCap.sh LinuxLoader.efi 5
    cp -f LinuxLoader.efi.cap "${PATH_OUT}/"
    cd -
fi
}

build_memcfg(){
    echo -e "BUILD MEMCFG $1 Started."
    local memcfg_dir="${PATH_PROJECT}/mem_config"
    local memcfg_file="memory_config.bin"
    local memcfg_target="$1"

    cd $memcfg_dir

    #compile and generate the memory config with the param: $MEM_CONF_FREQ and $MEM_CONF_CH
    make || exit 1

    cd -

    cp $memcfg_dir/$memcfg_file $memcfg_target

    if [[ -e "${memcfg_target}" ]]; then
        echo -e "${GREEN}BUILD MEMCFG to $memcfg_target Success!!${NORMAL}"
    else
        echo -e "${RED}BUILD MEMCFG to $memcfg_target Failed!!${NORMAL}"
        exit 1
    fi
}

build_pmcfg(){
    echo -e "BUILD PMCFG $1 Started."
    local pmcfg_dir="${PATH_PROJECT}/pm_config"
    local pmcfg_file="csu_pm_config.bin"
    local pmcfg_target="$1"

    cd $pmcfg_dir

    #compile and generate the pm config
    make || exit 1

    cd -

    cp $pmcfg_dir/$pmcfg_file $pmcfg_target

    if [[ -e "${pmcfg_target}" ]]; then
        echo -e "${GREEN}BUILD PMCFG to $pmcfg_target Success!!${NORMAL}"
    else
        echo -e "${RED}BUILD PMCFG to $pmcfg_target Failed!!${NORMAL}"
        exit 1
    fi
}

exec_cix_mkimage() {
    export PATH_PACKAGE_TOOL="${WORKSPACE}/edk2-non-osi/Platform/CIX/Sky1/PackageTool"
    export PATH_FIRMARES="${PATH_OUT}/Firmwares"
    export PATH_PROJECT="${WORKSPACE}/${UEFI_PROJECT_FOLDER}/${UEFI_PROJECT_PATH}/${UEFI_PROJECT}"

    if [ $# != 1 ]; then
        echo "Error input parameter for mkimage"
		exit 1
	fi

    local build_key_type=$1
    local path_out_temp
    local flash_all_file_name
    local flash_ota_file_name

    if [[ "${build_key_type}" == "pr" ]]; then
        path_out_temp="${PATH_OUT_PR}"
        flash_all_file_name="cix_flash_all"
        flash_ota_file_name="cix_flash_ota"
        cp -f "${PATH_PACKAGE_TOOL}/Firmwares/bootloader1.img" "${path_out_temp}/Firmwares/bootloader1.img"
        cp -f "${PATH_PACKAGE_TOOL}/Firmwares/bootloader2.img" "${path_out_temp}/Firmwares/bootloader2.img"
    else
        path_out_temp="${PATH_OUT_PR2}"
        flash_all_file_name="cix_flash_all2"
        flash_ota_file_name="cix_flash_ota2"
        cp -f "${PATH_PACKAGE_TOOL}/Firmwares2/bootloader1.img" "${path_out_temp}/Firmwares/bootloader1.img"
        cp -f "${PATH_PACKAGE_TOOL}/Firmwares2/bootloader2.img" "${path_out_temp}/Firmwares/bootloader2.img"
    fi

    local path_out_firmwares="${path_out_temp}/Firmwares"


    # copy require files to output
    cp  ${PATH_PACKAGE_TOOL}/Firmwares/*.bin "${path_out_temp}/Firmwares/"

    cp -r "${PATH_PACKAGE_TOOL}/Keys/" "${path_out_temp}"

    exec_blankfile "${path_out_temp}/Firmwares/dummy.bin" 8192

    # build project specific memory config
    if [[ -e "${PATH_PROJECT}/mem_config" ]]; then
        echo -e "${GREEN}found project specific memory config ${PATH_PROJECT}/mem_config${NORMAL}"
        build_memcfg "${path_out_firmwares}/memory_config.bin"
    fi

    # build project specific pm config
    if [[ -e "${PATH_PROJECT}/pm_config" ]]; then
        echo -e "${GREEN}found project specific pm config ${PATH_PROJECT}/pm_config${NORMAL}"
        build_pmcfg "${path_out_firmwares}/csu_pm_config.bin"
    fi

    # update project specific low level firmware
    if [[ -e "${PATH_PROJECT}/Firmwares/" ]]; then
        echo -e "${GREEN}found project specific firmware folder ${PATH_PROJECT}/Firmwares/${NORMAL}"
        cp ${PATH_PROJECT}/Firmwares/* ${path_out_firmwares}
    fi

    # check bootloader1 image
    if [[ ! -e "${path_out_firmwares}/bootloader1.img" ]]; then
        echo "ERROR: no file ${path_out_firmwares}/bootloader1.img"
        exit 1
    fi

    # check bootloader2 image
    if [[ ! -e "${path_out_firmwares}/bootloader2.img" ]]; then
        echo "ERROR: no file ${path_out_firmwares}/bootloader2.img"
        exit 1
    fi

	# Copy tools to output
    if [ "$(uname -m)" = "aarch64" ]; then
      cp  "${PATH_PACKAGE_TOOL}/AARCH64/cert_uefi_create_rsa" "${path_out_temp}"
      cp  "${PATH_PACKAGE_TOOL}/AARCH64/cix_package_tool" "${path_out_temp}"
      cp  "${PATH_PACKAGE_TOOL}/AARCH64/fiptool" "${path_out_temp}"
    else
      cp  "${PATH_PACKAGE_TOOL}/X86_64/cert_uefi_create_rsa" "${path_out_temp}"
      cp  "${PATH_PACKAGE_TOOL}/X86_64/cix_package_tool" "${path_out_temp}"
      cp  "${PATH_PACKAGE_TOOL}/X86_64/fiptool" "${path_out_temp}"
	  cp  "${PATH_PACKAGE_TOOL}/cix_regen_trusted_key_cert" "${path_out_temp}"
    fi
    cp ${PATH_PACKAGE_TOOL}/spi_flash_config_all.json ${path_out_temp}
    cp ${PATH_PACKAGE_TOOL}/spi_flash_config_ota.json ${path_out_temp}
    # update project specific spi flash layout
    if [[ -e "${PATH_PROJECT}/spi_flash_config_all.json" ]]; then
        echo -e "${GREEN}found project specific ${PATH_PROJECT}/spi_flash_config_all.json${NORMAL}"
        cp ${PATH_PROJECT}/spi_flash_config_all.json ${path_out_temp}
    fi

    if [[ -e "${PATH_PROJECT}/spi_flash_config_ota.json" ]]; then
        echo -e "${GREEN}found project specific ${PATH_PROJECT}/spi_flash_config_ota.json${NORMAL}"
        cp ${PATH_PROJECT}/spi_flash_config_ota.json ${path_out_temp}
    fi

    # update project specific oem key pair
    if [[ -e "${PATH_PROJECT}/Keys/oem_privatekey.pem" ]]; then
        echo -e "${GREEN}found project specific ${PATH_PROJECT}/Keys/oem_privatekey.pem${NORMAL}"
        cp ${PATH_PROJECT}/Keys/oem_privatekey.pem ${path_out_temp}/Keys/
    fi

    if [[ -e "${PATH_PROJECT}/Keys/oem_publickey.pem" ]]; then
        echo -e "${GREEN}found project specific ${PATH_PROJECT}/Keys/oem_publickey.pem${NORMAL}"
        cp ${PATH_PROJECT}/Keys/oem_publickey.pem ${path_out_temp}/Keys/
    fi

    # Generate bootloader3 image
    cd "${path_out_temp}"

    ./cix_regen_trusted_key_cert -p ${path_out_temp}/Keys/oem_publickey.pem -s ${path_out_temp}/Keys/oem_privatekey.pem -o ${path_out_temp}/certs/trusted_key_no.crt

    ./cert_uefi_create_rsa --key-alg rsa --key-size 3072 --hash-alg sha256 -p --ntfw-nvctr 223 \
        --nt-fw-cert ${path_out_temp}/certs/nt_fw_cert.crt \
        --nt-fw-key-cert ${path_out_temp}/certs/nt_fw_key.crt \
        --nt-fw-key ${path_out_temp}/Keys/oem_privatekey.pem \
        --non-trusted-world-key ${path_out_temp}/Keys/oem_privatekey.pem \
        --nt-fw ${PATH_OUT}/SKY1_BL33_UEFI.fd

    ./fiptool create \
        --trusted-key-cert ${path_out_temp}/certs/trusted_key_no.crt \
        --nt-fw-key-cert ${path_out_temp}/certs/nt_fw_key.crt \
        --nt-fw-cert ${path_out_temp}/certs/nt_fw_cert.crt \
        --nt-fw ${PATH_OUT}/SKY1_BL33_UEFI.fd \
        ${path_out_firmwares}/bootloader3.img
    cd -

    if [[ ! -e "${path_out_firmwares}/bootloader3.img" ]]; then
        echo "ERROR: no file ${path_out_firmwares}/bootloader3.img"
        exit 1
    fi

    # Generate spi flash image
    cd "${path_out_temp}"

	 echo "./cix_package_tool -c spi_flash_config_all.json -o ${flash_all_file_name}.bin"
    ./cix_package_tool -c spi_flash_config_all.json -o ${flash_all_file_name}.bin
    cp ${flash_all_file_name}.bin ${PATH_OUT}/${flash_all_file_name}.bin

    echo "./cix_package_tool -c spi_flash_config_ota.json -O ${flash_ota_file_name}.bin"
    ./cix_package_tool -c spi_flash_config_ota.json -O ${flash_ota_file_name}.bin
    cp ${flash_ota_file_name}.bin ${PATH_OUT}/${flash_ota_file_name}.bin

    cd -

    echo -e "${GREEN}Generate ${PATH_OUT}/${flash_all_file_name}.bin successful!${NORMAL}"

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

if [[ ! -e "${PATH_OUT_PR}" ]]; then
    mkdir -p "${PATH_OUT_PR}"
    mkdir -p "${PATH_OUT_PR}/Firmwares"
    mkdir -p "${PATH_OUT_PR}/Keys"
    mkdir -p "${PATH_OUT_PR}/certs"
fi

if [[ ! -e "${PATH_OUT_PR2}" ]]; then
    mkdir -p "${PATH_OUT_PR2}"
    mkdir -p "${PATH_OUT_PR2}/Firmwares"
    mkdir -p "${PATH_OUT_PR2}/Keys"
    mkdir -p "${PATH_OUT_PR2}/certs"
fi

if [ ! -z "$1" ]; then
    UEFI_PROJECT="$1"
fi

if [ -e "$WORKSPACE/edk2-project" ]; then
    PACKAGES_PATH="${PACKAGES_PATH}:$WORKSPACE/edk2-project"
fi

case "$UEFI_PROJECT" in
("Merak")
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    FASTBOOT_LOAD_TYPE="nvme"
    ;;
("OPI6")
    UEFI_PROJECT_FOLDER="edk2-project"
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    ;;
("Edge")
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    FASTBOOT_LOAD_TYPE="nvme"
    ;;
("CloudBook")
    UEFI_PROJECT_FOLDER="edk2-project"
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    ;;
("MGP1WSB")
    UEFI_PROJECT_FOLDER="edk2-project"
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    ;;
("SixUnited")
    UEFI_PROJECT_FOLDER="edk2-project"
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    ;;
("O6")
    UEFI_PROJECT_PATH="Platform/Radxa/Orion"
    FASTBOOT_LOAD_TYPE="nvme"
    ;;
("O6N")
    UEFI_PROJECT_PATH="Platform/Radxa/Orion"
    ;;
("android")
    UEFI_PROJECT_PATH="Platform/CIX/Sky1"
    UEFI_PROJECT="Merak"
    FASTBOOT_LOAD_TYPE="nvme"
    OS_SUPPORT_TYPE="android"
    ;;
("androidO6")
    UEFI_PROJECT_PATH="Platform/Radxa/Orion"
    UEFI_PROJECT="O6"
    FASTBOOT_LOAD_TYPE="nvme"
    OS_SUPPORT_TYPE="android"
    ;;
(*)
    echo -e "${RED}Unsupported Project ${UEFI_PROJECT}!!${NORMAL}"
    exit 1
    ;;
esac

echo "Build UEFI Project $UEFI_PROJECT with PATH ${UEFI_PROJECT_PATH}"

set -e

exec_build_uefi
exec_cix_mkimage pr
exec_cix_mkimage pr2
