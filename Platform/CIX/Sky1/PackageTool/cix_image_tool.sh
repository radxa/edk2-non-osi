#!/bin/bash
ScriptVersion=2024.v1.0
#PATH_ROOT=~/share
#CURRENT_DIR=${PATH_ROOT}/tool/sw_tools_open/host/cix_secure_boot_tool
#CURRENT_DIR=${PATH_ROOT}/tools/cix_binary/host/security/cix_secure_boot_tool
#BIN_PATH=${PATH_ROOT}/tools/cix_binary/host/security
CURRENT_DIR=$(pwd)

# Define all path for each part
KEYS_PATH=""
KEYS_PATH_RELATIVE=""
CERTS_PATH=${CURRENT_DIR}/certs
OUTPUT_PATH=${CURRENT_DIR}/out
UNPACK_PATH=${CURRENT_DIR}/unpack
RELEASE_FLAG=""

# Define all tool's name
FIP_TOOL=
CERT_CREATE_RSA=
CERT_CREATE_SM=

CERT_CREATE=

# Variables will be use in this script
INPUT_NAME=				#Input name
OUTPUT_NAME=			#Variable of output
KEY_TYPE=			    #Type of key

BL31_FILE_NAME=			#Variable of BL31 firmware name
BL32_FILE_NAME=			#Variable of BL32 firmware name
BL33_FILE_NAME=			#Variable of BL33 firmware name

OPERATION_FLAG=			#Operation flag

# Define variable for configuration file of mkimage
MKIMAGE_CONFIG_FILE=""

# Define all cert files which will generate during signing
TRUSTED_KEY_CERT=${CERTS_PATH}/trusted_key.crt
BL31_FW_KEY_CERT=${CERTS_PATH}/bl31_fw_key.crt
TOS_FW_KEY_CERT=${CERTS_PATH}/tos_fw_key.crt
NT_FW_KEY_CERT=${CERTS_PATH}/nt_fw_key.crt
BL31_FW_CONTENT_CERT=${CERTS_PATH}/bl31_fw_content.crt
TOS_FW_CONTENT_CERT=${CERTS_PATH}/tos_fw_cert.crt
NT_FW_CONTENT_CERT=${CERTS_PATH}/nt_fw_cert.crt



# Define packaged image's name
FIP_IMAGE=${OUTPUT_PATH}/fip.bin

#-----------------------------------------------------------------------
# FUNCTION: usage
# DESCRIPTION:  Display usage information.
#-----------------------------------------------------------------------
function usage() {
    cat << EOT

cix_image_tool.sh version ${ScriptVersion}
You can use below command to use this tool, it support long & short options:
./cix_image_tool.sh [Options]...

Options:
  -h, --help                    Display this message
  -v, --verify                  Verify package image
  -k, --keys                    Generate all keys
  -p, --package                 Sign & package second boot stage's images
  -j, --json                    Json configuration file for packaging bootrom
  -X, --bf31                    Image name of BL31 firmware
  -Y, --bf32                    Image name of BL31 firmware
  -Z, --bf33                    Image name of BL31 firmware
  -u, --unpack                  Unpack bootrm or fip image
  -T, --type                    Type of key(sm2/rsa2048/3072)
  -K, --Keypath                 Key path for package second binary

Exit status:
  0   if OK,
  !=0 if serious problems.

Example:
  1) Use below command to sign & package blx images to fip image:
    ./cix_image_tool.sh -p -T [sm2, rsa2048, rsa3072] -K <keyspath> --bf31 BL31_FW_IMAGE --bf32 TEE_FW_IMAGE --bf33 UEFI_FW_IMAGE

  2) Use below command to verify fip image:
    ./cix_image_tool.sh -v -T [sm2, rsa2048, rsa3072] -K <keyspath> -i FIP_IMAGE --bf31 BL31_FW_IMAGE --bf32 TEE_FW_IMAGE --bf33 UEFI_FW_IMAGE

  3) Use below command to unpack fip image:
    ./cix_image_tool.sh -u -T [sm2, rsa2048, rsa3072] -i FIP_IMAGE
EOT
}

#-----------------------------------------------------------------------
# FUNCTION: error_print
# DESCRIPTION:  print error info.
#-----------------------------------------------------------------------
function error_print() {
	echo -e "\033[31m $1 \033[0m"
}



#-----------------------------------------------------------------------
# FUNCTION: check_path
# DESCRIPTION:  Check if path was exist, if not, create it.
#-----------------------------------------------------------------------
function check_path() {
	if [ ! -d "$1" ]; then
		mkdir $1
	fi
}


#-----------------------------------------------------------------------
# FUNCTION: check_file
# DESCRIPTION:  Check if file was exist. if return 1, file is not exist
#               otherwise, file was exist
#-----------------------------------------------------------------------
function check_file() {
	if [ ! -f "$1" ]; then
		return 1
	else
		return 0
	fi
}

#-----------------------------------------------------------------------
# FUNCTION: check_sign_keys
# DESCRIPTION:  Check if keys was exist
#-----------------------------------------------------------------------
function check_if_key_exist() {
	check_file $OEM_KEY
	if [ $? == 0 ]; then
		error_print "[Error]: oem_key=$OEM_KEY is exist, please make sure keys/ empty"
		return 1
	fi

	check_file $TRUSTED_WORLD_KEY
	if [ $? == 0 ]; then
		error_print "[Error]: trusted_world_key=$TRUSTED_WORLD_KEY is exist, please make sure keys/ empty"
		return 1
	fi

	check_file $NON_TRUSTED_WORLD_KEY
	if [ $? == 0 ]; then
		error_print "[Error]: non_trusted_world_key=$NON_TRUSTED_WORLD_KEY is exist, please make sure keys/ empty"
		return 1
	fi

	check_file $BL31_KEY
	if [ $? == 0 ]; then
		error_print "[Error]: bl31_key=$BL31_KEY is exist, please make sure keys/ empty"
		return 1
	fi

	check_file $BL32_KEY
	if [ $? == 0 ]; then
		error_print "[Error]: bl32_key=$BL32_KEY is exist, please make sure keys/ empty"
		return 1
	fi

	check_file $BL33_KEY
	if [ $? == 0 ]; then
		error_print "[Error]: bl33_key=$BL33_KEY is exist, please make sure keys/ empty"
		return 1
	fi
	return 0
}

#-----------------------------------------------------------------------
# FUNCTION: check_sign_parameter
# DESCRIPTION:  Check if parameters was right when do operation of signing
#-----------------------------------------------------------------------
function check_sign_firmware_parameter() {
	if [ ! -z "$BL31_FILE_NAME" ] ; then
		check_file $BL31_FILE_NAME
		if [ $? != 0 ]; then
			error_print "[Error]: Don't input firmware name of BL31"
			return 1
		fi
	fi

	if [ ! -z "$BL32_FILE_NAME" ] ; then
		check_file $BL32_FILE_NAME
		if [ $? != 0 ]; then
			error_print "[Error]: Don't input firmware name of BL32"
			return 1
		fi
	fi

	if [ ! -z "$BL33_FILE_NAME" ] ; then
		check_file $BL33_FILE_NAME
		if [ $? != 0 ]; then
			error_print "[Error]: Don't input firmware name of BL33"
			return 1
		fi
	fi

	return 0
}


#-----------------------------------------------------------------------
# FUNCTION: check_sign_keys
# DESCRIPTION:  Check if keys was exist
#-----------------------------------------------------------------------
function check_all_keys_file() {
	check_file $OEM_KEY
	if [ $? != 0 ]; then
		error_print "[Error]: oem_key=$OEM_KEY is not exist, please put right key"
		return 1
	fi

	check_file $TRUSTED_WORLD_KEY
	if [ $? != 0 ]; then
		error_print "[Error]: trusted_world_key=$TRUSTED_WORLD_KEY is not exist, please put right key"
		return 1
	fi

	check_file $NON_TRUSTED_WORLD_KEY
	if [ $? != 0 ]; then
		error_print "[Error]: non_trusted_world_key=$NON_TRUSTED_WORLD_KEY is not exist, please put right key"
		return 1
	fi

	check_file $BL31_KEY
	if [ $? != 0 ]; then
		error_print "[Error]: bl31_key=$BL31_KEY is not exist, please put right key"
		return 1
	fi

	check_file $BL32_KEY
	if [ $? != 0 ]; then
		error_print "[Error]: bl32_key=$BL32_KEY is not exist, please put right key"
		return 1
	fi

	check_file $BL33_KEY
	if [ $? != 0 ]; then
		error_print "[Error]: bl33_key=$BL33_KEY is not exist, please put right key"
		return 1
	fi
	return 0
}


#-----------------------------------------------------------------------
# FUNCTION: check_all_fip_sub_images
# DESCRIPTION:  Check if all sub images in fip are exist
#-----------------------------------------------------------------------
function check_all_fip_sub_images() {
	check_file $BL31_FILE_NAME
	if [ $? != 0 ]; then
		error_print "[Error]: bl31_fw=$BL31_FILE_NAME is not exist"
		return 1
	fi

	check_file $BL32_FILE_NAME
	if [ $? != 0 ]; then
		error_print "[Error]: bl32_fw=$BL32_FILE_NAME is not exist"
		return 1
	fi

	check_file $BL33_FILE_NAME
	if [ $? != 0 ]; then
		error_print "[Error]: bl33_fw=$BL32_FILE_NAME is not exist"
		return 1
	fi

	check_file $TRUSTED_KEY_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: trusted_key_cert=$TRUSTED_KEY_CERT is not exist"
		return 1
	fi

	check_file $BL31_FW_KEY_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: bl31_fw_key_cert=$BL31_FW_KEY_CERT is not exist"
		return 1
	fi

	check_file $TOS_FW_KEY_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: tos_fw_key_cert=$TOS_FW_KEY_CERT is not exist"
		return 1
	fi

	check_file $NT_FW_KEY_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: nt_fw_key_cert=$NT_FW_KEY_CERT is not exist"
		return 1
	fi

	check_file $BL31_FW_CONTENT_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: bl31_fw_content_cert=$BL31_FW_CONTENT_CERT is not exist"
		return 1
	fi

	check_file $TOS_FW_CONTENT_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: bl32_fw_content_cert=$TOS_FW_CONTENT_CERT is not exist"
		return 1
	fi

	check_file $NT_FW_CONTENT_CERT
	if [ $? != 0 ]; then
		error_print "[Error]: bl33_fw_content_cert=$NT_FW_CONTENT_CERT is not exist"
		return 1
	fi
	return 0
}


#-----------------------------------------------------------------------
# FUNCTION: sign_blx
# DESCRIPTION:  Sign blx images with keys
#-----------------------------------------------------------------------
function sign_blx() {
	check_sign_firmware_parameter
	if [ $? != 0 ]; then
		return 1
	fi

	check_all_keys_file
	if [ $? != 0 ]; then
		return 1
	fi

	if [ "$KEY_TYPE" == "rsa2048" ]; then
		${CERT_CREATE} --key-alg rsa --key-size 2048 \
		--hash-alg sha256 -p --tfw-nvctr 31 --ntfw-nvctr 223 \
		--rot-key ${OEM_KEY} \
		--trusted-world-key ${TRUSTED_WORLD_KEY} \
		--non-trusted-world-key ${NON_TRUSTED_WORLD_KEY} \
		--soc-fw-key ${BL31_KEY} \
		--tos-fw-key ${BL32_KEY} \
		--nt-fw-key ${BL33_KEY} \
		--trusted-key-cert ${TRUSTED_KEY_CERT} \
		--soc-fw-key-cert ${BL31_FW_KEY_CERT} \
		--tos-fw-key-cert ${TOS_FW_KEY_CERT} \
		--nt-fw-key-cert ${NT_FW_KEY_CERT} \
		--soc-fw-cert ${BL31_FW_CONTENT_CERT} \
		--tos-fw-cert ${TOS_FW_CONTENT_CERT} \
		--nt-fw-cert ${NT_FW_CONTENT_CERT} \
		--soc-fw ${BL31_FILE_NAME} \
		--tos-fw ${BL32_FILE_NAME} \
		--nt-fw ${BL33_FILE_NAME}
	elif [ "$KEY_TYPE" == "rsa3072" ]; then
		${CERT_CREATE} --key-alg rsa --key-size 3072 \
		--hash-alg sha256 -p --tfw-nvctr 31 --ntfw-nvctr 223 \
		--rot-key ${OEM_KEY} \
		--trusted-world-key ${TRUSTED_WORLD_KEY} \
		--non-trusted-world-key ${NON_TRUSTED_WORLD_KEY} \
		--soc-fw-key ${BL31_KEY} \
		--tos-fw-key ${BL32_KEY} \
		--nt-fw-key ${BL33_KEY} \
		--trusted-key-cert ${TRUSTED_KEY_CERT} \
		--soc-fw-key-cert ${BL31_FW_KEY_CERT} \
		--tos-fw-key-cert ${TOS_FW_KEY_CERT} \
		--nt-fw-key-cert ${NT_FW_KEY_CERT} \
		--soc-fw-cert ${BL31_FW_CONTENT_CERT} \
		--tos-fw-cert ${TOS_FW_CONTENT_CERT} \
		--nt-fw-cert ${NT_FW_CONTENT_CERT} \
		--soc-fw ${BL31_FILE_NAME} \
		--tos-fw ${BL32_FILE_NAME} \
		--nt-fw ${BL33_FILE_NAME}
	elif [ "$KEY_TYPE" == "sm2" ]; then
		${CERT_CREATE} --key-alg sm2 \
		--hash-alg sm3 -p --tfw-nvctr 31 --ntfw-nvctr 223 \
		--rot-key ${OEM_KEY} \
		--trusted-world-key ${TRUSTED_WORLD_KEY} \
		--non-trusted-world-key ${NON_TRUSTED_WORLD_KEY} \
		--soc-fw-key ${BL31_KEY} \
		--tos-fw-key ${BL32_KEY} \
		--nt-fw-key ${BL33_KEY} \
		--trusted-key-cert ${TRUSTED_KEY_CERT} \
		--soc-fw-key-cert ${BL31_FW_KEY_CERT} \
		--tos-fw-key-cert ${TOS_FW_KEY_CERT} \
		--nt-fw-key-cert ${NT_FW_KEY_CERT} \
		--soc-fw-cert ${BL31_FW_CONTENT_CERT} \
		--tos-fw-cert ${TOS_FW_CONTENT_CERT} \
		--nt-fw-cert ${NT_FW_CONTENT_CERT} \
		--soc-fw ${BL31_FILE_NAME} \
		--tos-fw ${BL32_FILE_NAME} \
		--nt-fw ${BL33_FILE_NAME}
	fi

	if [ $? != 0 ]; then
		error_print "[Error]: execute ${CERT_CREATE} fail"
		return 1
	fi
}


#-----------------------------------------------------------------------
# FUNCTION: package_fip
# DESCRIPTION: Package blx & certificates into fip
#-----------------------------------------------------------------------
function package_fip() {
	check_all_fip_sub_images
	if [ $? != 0 ]; then
		return 1
	fi
    
    echo	${FIP_TOOL} create \
	--soc-fw ${BL31_FILE_NAME} \
	--tos-fw ${BL32_FILE_NAME} \
	--nt-fw ${BL33_FILE_NAME} \
	--trusted-key-cert ${TRUSTED_KEY_CERT} \
	--soc-fw-key-cert ${BL31_FW_KEY_CERT} \
	--tos-fw-key-cert ${TOS_FW_KEY_CERT} \
	--nt-fw-key-cert ${NT_FW_KEY_CERT} \
	--soc-fw-cert ${BL31_FW_CONTENT_CERT} \
	--tos-fw-cert ${TOS_FW_CONTENT_CERT} \
	--nt-fw-cert ${NT_FW_CONTENT_CERT} \
    $1

	${FIP_TOOL} create \
	--soc-fw ${BL31_FILE_NAME} \
	--tos-fw ${BL32_FILE_NAME} \
	--nt-fw ${BL33_FILE_NAME} \
	--trusted-key-cert ${TRUSTED_KEY_CERT} \
	--soc-fw-key-cert ${BL31_FW_KEY_CERT} \
	--tos-fw-key-cert ${TOS_FW_KEY_CERT} \
	--nt-fw-key-cert ${NT_FW_KEY_CERT} \
	--soc-fw-cert ${BL31_FW_CONTENT_CERT} \
	--tos-fw-cert ${TOS_FW_CONTENT_CERT} \
	--nt-fw-cert ${NT_FW_CONTENT_CERT} \
	$1
	if [ $? != 0 ]; then
		error_print "[Error]: execute ${FIP_TOOL} fail"
		return 1
	fi
}


#-----------------------------------------------------------------------
# FUNCTION: package_and_sign_blx
# DESCRIPTION:  Sign blx images then package them to fip
#-----------------------------------------------------------------------
function package_and_sign_blx() {
	sign_blx
	if [ $? != 0 ]; then
		return 1
	fi

	if [ ! -z "$OUTPUT_NAME" ]; then
		package_fip $OUTPUT_NAME
	else
		package_fip ${FIP_IMAGE}
	fi
	if [ $? != 0 ]; then
		return 1
	else
		return 0
	fi
}

#-----------------------------------------------------------------------
# FUNCTION: compare_files
# DESCRIPTION:  Verify fip image
#-----------------------------------------------------------------------
function compare_files() {
	diff $1 $2 > /dev/null
	if [ $? != 0 ]; then
		echo "$1 was different with $2"
		return 1
	else
		return 0
	fi
}

#-----------------------------------------------------------------------
# FUNCTION: compare_unpack_raw_image
# DESCRIPTION:  Compare unpack image with raw image
#-----------------------------------------------------------------------
function compare_unpack_raw_image() {
# Compare each sub image in fip
	compare_files ${BL31_FILE_NAME} ${UNPACK_PATH}/soc-fw.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${BL32_FILE_NAME} ${UNPACK_PATH}/tos-fw.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${BL33_FILE_NAME} ${UNPACK_PATH}/nt-fw.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${TRUSTED_KEY_CERT} ${UNPACK_PATH}/trusted-key-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${BL31_FW_KEY_CERT} ${UNPACK_PATH}/soc-fw-key-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${TOS_FW_KEY_CERT} ${UNPACK_PATH}/tos-fw-key-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${NT_FW_KEY_CERT} ${UNPACK_PATH}/nt-fw-key-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${BL31_FW_CONTENT_CERT} ${UNPACK_PATH}/soc-fw-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${TOS_FW_CONTENT_CERT} ${UNPACK_PATH}/tos-fw-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	compare_files ${NT_FW_CONTENT_CERT} ${UNPACK_PATH}/nt-fw-cert.bin
	if [ $? != 0 ]; then
		return 1
	fi

	return 0
}

#-----------------------------------------------------------------------
# FUNCTION: verify_signature_fip
# DESCRIPTION:  Verify fip image
#-----------------------------------------------------------------------
function verify_signature_fip() {

	if [ "$KEY_TYPE" == "rsa2048" ]; then
		${CERT_CREATE} --key-alg rsa --key-size 2048 -v \
		--rot-key ${OEM_PUBLIC_KEY} \
		--trusted-key-cert unpack/trusted-key-cert.bin \
		--soc-fw-key-cert unpack/soc-fw-key-cert.bin \
		--tos-fw-key-cert unpack/tos-fw-cert.bin \
		--nt-fw-key-cert unpack/nt-fw-key-cert.bin \
		--soc-fw-cert unpack/soc-fw-cert.bin \
		--tos-fw-cert unpack/tos-fw-cert.bin \
		--nt-fw-cert unpack/nt-fw-cert.bin \
		--soc-fw unpack/soc-fw.bin \
		--tos-fw unpack/tos-fw.bin \
		--nt-fw unpack/nt-fw.bin
		if [ $? != 0 ]; then
			return 1
		else
			return 0
		fi
	elif [ "$KEY_TYPE" == "rsa3072" ]; then
		${CERT_CREATE} --key-alg rsa --key-size 3072 -v \
		--rot-key ${OEM_PUBLIC_KEY} \
		--trusted-key-cert unpack/trusted-key-cert.bin \
		--soc-fw-key-cert unpack/soc-fw-key-cert.bin \
		--tos-fw-key-cert unpack/tos-fw-cert.bin \
		--nt-fw-key-cert unpack/nt-fw-key-cert.bin \
		--soc-fw-cert unpack/soc-fw-cert.bin \
		--tos-fw-cert unpack/tos-fw-cert.bin \
		--nt-fw-cert unpack/nt-fw-cert.bin \
		--soc-fw unpack/soc-fw.bin \
		--tos-fw unpack/tos-fw.bin \
		--nt-fw unpack/nt-fw.bin
		if [ $? != 0 ]; then
			return 1
		else
			return 0
		fi
	elif [ "$KEY_TYPE" == "sm2" ]; then
		${CERT_CREATE} --key-alg sm2 -v \
		--rot-key ${OEM_PUBLIC_KEY} \
		--trusted-key-cert unpack/trusted-key-cert.bin \
		--soc-fw-key-cert unpack/soc-fw-key-cert.bin \
		--tos-fw-key-cert unpack/tos-fw-cert.bin \
		--nt-fw-key-cert unpack/nt-fw-key-cert.bin \
		--soc-fw-cert unpack/soc-fw-cert.bin \
		--tos-fw-cert unpack/tos-fw-cert.bin \
		--nt-fw-cert unpack/nt-fw-cert.bin \
		--soc-fw unpack/soc-fw.bin \
		--tos-fw unpack/tos-fw.bin \
		--nt-fw unpack/nt-fw.bin
		if [ $? != 0 ]; then
			return 1
		else
			return 0
		fi
	fi
}


#-----------------------------------------------------------------------
# FUNCTION: unpack_fip
# DESCRIPTION:  Unpack fip image
#-----------------------------------------------------------------------
function unpack_fip() {
	# Check if unpack path was exist
	check_path ${UNPACK_PATH}

	if [ ! -z "$INPUT_NAME" ]; then
		${FIP_TOOL} unpack --out ${UNPACK_PATH} --force ${INPUT_NAME}
	else
		error_print "Don't assign fip image, so use default fip image's name"
		${FIP_TOOL} unpack --out ${UNPACK_PATH} --force ${FIP_IMAGE}
	fi

	if [ $? != 0 ]; then
		return 1
	else
		echo -e "\033[42;36m Note: All sub-images are saved in path of "unpack/" \033[0m"
		return 0
	fi
}



#-----------------------------------------------------------------------
# FUNCTION: verify_fip
# DESCRIPTION:  Verify fip image
#-----------------------------------------------------------------------
function verify_fip() {
	# Check if input parameter was right
	check_sign_firmware_parameter
	if [ $? != 0 ]; then
		return 1
	fi

	check_all_keys_file
	if [ $? != 0 ]; then
		return 1
	fi

	# Check if unpack path was exist
	check_path ${UNPACK_PATH}

	# Unpack fip file
	${FIP_TOOL} unpack --out ${UNPACK_PATH} --force ${INPUT_NAME}
	if [ $? != 0 ]; then
		error_print "[Error]: Execute ${FIP_TOOL} fail"
		return 1
	fi

	compare_unpack_raw_image
	if [ $? != 0 ]; then
		return 1
	fi

	verify_signature_fip
	if [ $? != 0 ]; then
		return 1
	else
		return 0
	fi
}


#-----------------------------------------------------------------------
# FUNCTION: verify_package_image
# DESCRIPTION:  Verify if packaged image is right
#-----------------------------------------------------------------------
function verify_package_image() {
    echo "**********************************************************"
    echo "*                    Verify fip image                    *"
    echo "**********************************************************"
    echo ""
    verify_fip
    if [ $? != 0 ]; then
        usage
        echo -e "\033[43;31m Verify fip image fail \033[0m"
        return 1
    else
        echo -e "\033[43;31m Verify fip image successful \033[0m"
        return 0
    fi
}


# Check number of parameter
if [ $# -eq 0 ]; then usage; exit 1; fi

if [[ ! -f "${PATH_PACKAGE_TOOL}/cix_image_tool.sh" ]]; then
   echo -e "\e[31m Can not find PATH_PACKAGE_TOOL path\e[0m"
   exit 1
fi

FIP_TOOL=${PATH_PACKAGE_TOOL}/fiptool
CERT_CREATE_RSA=${PATH_PACKAGE_TOOL}/cert_create_rsa
CERT_CREATE_SM=${PATH_PACKAGE_TOOL}/cert_create_sm

check_path ${CERTS_PATH}


# parse options:
RET=`getopt -o hvo:K:gksFSt:pj:X:Y:Z:ci:T:u \
--long help,verify,output:,Keypath:,genKey,keys,sign,First,\
Second,tar:,package,json:,bf31:,bf32:,bf33:,calHash,input:,type:,unpack \
-n ' * ERROR' -- "$@"`

if [ $? != 0 ] ; then echo "cix_image_tool.sh exited with doing nothing." >&2 ; exit 1 ; fi

# Note the quotes around $RET: they are essential!
eval set -- "$RET"

# set option values
while true; do
	case "$1" in
		-h | --help )
			usage;
			exit 1;;
		-v | --verify )
			OPERATION_FLAG=verify;
			shift 1 ;;
		-i | --input )
			INPUT_NAME=$2;
			shift 2 ;;            
		-o | --output )
			OUTPUT_NAME=$2;
			shift 2 ;;
		-K | --Keypath )
			KEYS_PATH_RELATIVE=$2;
			shift 2 ;;
		-T | --type )
			KEY_TYPE=$2;
			shift 2 ;;
		-k | --keys )
			GEN_ALL_KEYS_FLAG=Y;
			shift 1 ;;
		-u | --unpack )
			OPERATION_FLAG=unpack;
			shift 1 ;;
		-p | --package )
			OPERATION_FLAG=package;
			shift 1 ;;
		-j | --json )
			MKIMAGE_CONFIG_FILE=$2;
			shift 2 ;;
		-X | --bf31 )
			BL31_FILE_NAME=$2;
			shift 2 ;;
		-Y | --bf32 )
			BL32_FILE_NAME=$2;
			shift 2 ;;
		-Z | --bf33 )
			BL33_FILE_NAME=$2;
			shift 2 ;;
		-- )
			shift;
			break ;;
		* )
			echo "internal error!" ;
			exit 1 ;;
	esac
done



if [ -z "$KEYS_PATH_RELATIVE" ]; then
	KEYS_PATH=${CURRENT_DIR}/keys
else
	KEYS_PATH=${CURRENT_DIR}/${KEYS_PATH_RELATIVE}
fi

if [ "$KEY_TYPE" == "rsa2048" ]; then
	CERT_CREATE=${CERT_CREATE_RSA}
elif [ "$KEY_TYPE" == "rsa3072" ]; then
	CERT_CREATE=${CERT_CREATE_RSA}
elif [ "$KEY_TYPE" == "sm2" ]; then
	CERT_CREATE=${CERT_CREATE_SM}
else
	if [ "$OPERATION_FLAG" != "tar" ]; then
		error_print "Please Assign key Type for operation: rsa or sm2"
	fi
fi
# Define all keys file name which will be used in tool
OEM_KEY=${KEYS_PATH}/oem_privatekey.pem
TRUSTED_WORLD_KEY=${KEYS_PATH}/trusted_world_privatekey.pem
NON_TRUSTED_WORLD_KEY=${KEYS_PATH}/non_trusted_world_privatekey.pem
BL31_KEY=${KEYS_PATH}/bl31_privatekey.pem
BL32_KEY=${KEYS_PATH}/bl32_privatekey.pem
BL33_KEY=${KEYS_PATH}/bl33_privatekey.pem

# Define Public key file name
OEM_PUBLIC_KEY=${KEYS_PATH}/oem_publickey.pem
OEM_HASH_ROTPK=${KEYS_PATH}/hash_oem_rotpk.md

case $OPERATION_FLAG in
	"verify" )
		verify_package_image
		if [ $? != 0 ]; then
			echo -e "\033[43;31m Verify fail \033[0m"
			exit 1
		else
			echo -e "\033[43;31m Verify successful \033[0m"
			exit 0
		fi
		;;
	"package" )
        echo "**********************************************************"
        echo "*               Package & sign fip image                 *"
        echo "**********************************************************"
        echo ""
        package_and_sign_blx
        if [ $? != 0 ]; then
            usage
            echo -e "\033[43;31m Package fip image fail \033[0m"
            exit 1
        else
            echo -e "\033[43;31m Package fip image successful \033[0m"
            exit 0
        fi
		;;
	"unpack" )
        echo "**********************************************************"
        echo "*                   Unpack fip image                     *"
        echo "**********************************************************"
        echo ""
        unpack_fip
        if [ $? != 0 ]; then
            usage
            echo -e "\033[43;31m Unpack fip image fail \033[0m"
            exit 1
        else
            echo -e "\033[43;31m Unpack fip image successful \033[0m"
            exit 0
        fi
		;;
	* )
		echo "wrong operation"
		exit 1 ;;
esac
