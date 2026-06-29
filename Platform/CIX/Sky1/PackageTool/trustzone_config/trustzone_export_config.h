/*
 * Copyright 2024 - Cix Technology Group Co., Ltd. All Rights Reserved.
 */
#ifndef __TRUSTZONE_EXPORT_CONFIG_H__
#define __TRUSTZONE_EXPORT_CONFIG_H__

#include <stdint.h>

#define TABLE_SIGNATURE( x, y, m, n )                                              \
    ( uint32_t )( ( 0xFF & (uint8_t)( x ) ) | ( ( 0xFF & (uint8_t)( y ) ) << 8 ) | \
                  ( ( 0xFF & (uint8_t)( m ) ) << 16 ) | ( ( 0xFF & (uint8_t)( n ) ) << 24 ) )
#define TABLE_ALIGN_U32(_size)            (((_size) + 0x3) & ~0x3)
#define TABLE_ALIGN_U32_PADDING(_size)    (TABLE_ALIGN_U32(_size) - (_size))

#define TRUSTZONE_CONFIG_SIGNATURE TABLE_SIGNATURE('T', 'Z', 'C', 'F')

/* trustzone-config current supported version (v1.0) */
#define TRUSTZONE_CONFIG_VERSION_MAJOR  1
#define TRUSTZONE_CONFIG_VERSION_MINOR  0



#pragma pack(push, 1)

//Secure Storage Type
typedef enum {
    SEC_STORAGE_TYPE_NOF_DISABLED    = 0x00,  // Secure Storage Disabled
    SEC_STORAGE_TYPE_NOF_ENABLED    = 0x01,  // Secure Storage Enabled
    SEC_STORAGE_TYPE_INVALID = 0xFF
} secure_storage_type_e;

/**
 * @brief Configuration table header structure (corresponds to Table Header segment: 0x00-0x01 bytes)
 * Stores version and total length information, serves as the starting identifier of the configuration table
 */
typedef struct {
    uint8_t version_id;    // 0x00 byte: Version ID, fixed as TRUSTZONE_CONFIG_VERSION_MAJOR (0x01)
    uint8_t length;       // 0x01 byte: Total length of configuration table (including Header), unit: bytes
} trustzone_config_header_t;

/**
 * @brief Configuration table data structure (corresponds to Table Data segment: 0x02-0x0B bytes)
 * Stores SPE enable, secure storage type, address and size, all in Little Endian format
 */
typedef struct {
    uint8_t  spe_feature_en;        // 0x02 byte: SPE feature enable (0x00/0xFF=disabled, 0x01=enabled)
    uint8_t  secure_storage_type;   // 0x03 byte: Secure storage type (values from secure_storage_type_e)
    uint32_t secure_storage_addr;   // 0x04-0x07 bytes: Secure storage address (Little Endian)
    uint32_t secure_storage_size;   // 0x08-0x0B bytes: Secure storage size (Little Endian, unit: bytes)
} trustzone_config_data_t;

/**
 * @brief Trustzone core configuration structure
 * Combines header and data segments to form complete configuration content
 */
typedef struct {
    trustzone_config_header_t header;  // Configuration table header
    trustzone_config_data_t   data;    // Configuration table data
} trustzone_export_config_t;

/**
 * @brief Configuration structure with CRC checks
 * Adds version, timestamp, CRC checks to ensure configuration integrity and tamper resistance
 */
typedef struct {
    uint32_t version_major : 16;  // Major version number (TRUSTZONE_CONFIG_VERSION_MAJOR)
    uint32_t version_minor : 16;  // Minor version number (TRUSTZONE_CONFIG_VERSION_MINOR)
    uint32_t timestamp;           // Configuration generation timestamp
    uint32_t length;              // Total configuration length (including CRC segment)
    uint32_t signature;           // Configuration signature (TRUSTZONE_CONFIG_SIGNATURE)
    uint32_t crc1;                // Primary CRC check (covers version~signature fields)
    uint32_t crc2;                // Secondary CRC check (covers trustzone_export_config_t field)
    trustzone_export_config_t config;  // Core configuration content
    uint8_t padding[TABLE_ALIGN_U32_PADDING(sizeof(trustzone_export_config_t))];  // 32-bit alignment padding
} trustzone_export_config_crc_t;

#pragma pack(pop)

#endif
