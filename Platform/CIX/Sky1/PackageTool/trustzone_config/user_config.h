/*
 * Copyright 2024 - Cix Technology Group Co., Ltd. All Rights Reserved.
 */
#ifndef __USER_CONFIG_H__
#define __USER_CONFIG_H__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "trustzone_export_config.h"

#ifndef TRUSTZONE_CONFIG_ENABLE
#define TRUSTZONE_CONFIG_ENABLE 1
#endif


#if TRUSTZONE_CONFIG_ENABLE
/**
 * @brief Trustzone configuration instance (modify according to actual hardware parameters)
 * Field values must match hardware design, especially confirm physical memory range for secure storage address/size
 */
static trustzone_export_config_t trustzone_config = {
    .header = {
        .version_id = TRUSTZONE_CONFIG_VERSION_MAJOR,  // 0x00 byte: Version ID=0x01
        .length = sizeof(trustzone_export_config_t)    // 0x01 byte: Total length=12 bytes (header 2 bytes + data 10 bytes)
    },
    .data = {
        .spe_feature_en = 0x01,                        // 0x02 byte: Enable SPE feature
        .secure_storage_type = SEC_STORAGE_TYPE_NOF_ENABLED,// 0x03 byte: Secure storage type=Enabled
        .secure_storage_addr = 0x600000,             // 0x04-0x07 bytes: Secure storage address (Little Endian, physical address 0x00600000)
        .secure_storage_size = 0x200000              // 0x08-0x0B bytes: Secure storage size is 2m

    }
};


#endif  // TRUSTZONE_CONFIG_ENABLE

#endif  // __USER_CONFIG_H__
