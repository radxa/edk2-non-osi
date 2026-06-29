/*
 * Copyright 2024 - Cix Technology Group Co., Ltd. All Rights Reserved.
 */
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
#include <time.h>

#include "trustzone_export_config.h"
#include "user_config.h"

#define TRUSTZONE_CONFIG_BIN_SIZE  (4096)

#define ARRAY_LENGTH(_a)    (sizeof(_a) / sizeof(_a[0]))

#define PROJECT_NAME    "trustzone"
#define VALID           (0)
#define INVALID         (1)
trustzone_export_config_crc_t  g_config;

time_t CixEpoch ()
{
    struct tm specific_time = {0};

    specific_time.tm_year = 2021 - 1900;   // 2021
    specific_time.tm_mon  = 10 - 1;        // Oct.
    specific_time.tm_mday = 15;            // 15th
    specific_time.tm_hour = 9;             // 9 AM
    specific_time.tm_min  = 0;             // 0 min
    specific_time.tm_sec  = 0;             // 0 sec

    return mktime(&specific_time);
}

_Static_assert(((sizeof(g_config)) & 0x3) == 0,
    "TrustZone config block size must be 4-byte aligned!");

static bool double_check_sum(void * start, uint32_t length, uint64_t * sum64, bool do_check)
{
    uint32_t * ptr = (uint32_t *) start;
    uint32_t cka = 0, ckb = 0;

    assert((length & 0x3) == 0);

    for(uint32_t i = 0; i * 4 < length; i++) {
        cka += ptr[i];
        ckb += cka;
    }

    if (do_check) {
        if (sum64) {
            if ( (uint32_t)(*sum64 >> 32) == cka && (uint32_t)(*sum64) == ckb ) {
                return true;
            }
        }
    } else if (sum64) {
        *sum64 = ((uint64_t)cka << 32) + (uint64_t)ckb;
        return true;
    }

    return false;
}


/**
 * @brief Dump secure storage type in human-readable format
 * @param storage_type Secure storage type value
 */
static void dump_secure_storage_type(uint8_t storage_type)
{
    switch (storage_type) {
        case SEC_STORAGE_TYPE_NOF_DISABLED:
            printf("Disabled");
            break;
        case SEC_STORAGE_TYPE_NOF_ENABLED:
            printf("Enabled");
            break;
        case SEC_STORAGE_TYPE_INVALID:
            printf("INVALID");
            break;
        default:
            printf("Unknown (0x%02X)", storage_type);
            break;
    }
}

/**
 * @brief Dump configuration details
 */
static void dump_config()
{
    time_t timestamp = CixEpoch() + g_config.timestamp;

    printf("TrustZone Configuration Details:\n");
    printf("===============================\n");
    printf("Version      : %u.%u\n", g_config.version_major, g_config.version_minor);
    printf("Timestamp    : %u - %s", g_config.timestamp, ctime((const time_t *)&timestamp));
    printf("Length       : %u bytes\n", g_config.length);
    printf("Signature    : 0x%08X\n", g_config.signature);
    printf("CRC1         : 0x%08X\n", g_config.crc1);
    printf("CRC2         : 0x%08X\n", g_config.crc2);
    printf("\nConfiguration Header:\n");

    printf("  Version ID : 0x%02X\n", g_config.config.header.version_id);
    printf("  Length     : %u bytes\n", g_config.config.header.length);

    printf("\nConfiguration Data:\n");
    printf("  SPE Feature Enable : %s\n",
           g_config.config.data.spe_feature_en ? "Enabled (0x01)" : "Disabled (0x00)");
    printf("  Secure Storage Type : ");
    dump_secure_storage_type(g_config.config.data.secure_storage_type);
    printf(" (0x%02X)\n", g_config.config.data.secure_storage_type);
    printf("  Secure Storage Addr : 0x%08X\n", g_config.config.data.secure_storage_addr);
    printf("  Secure Storage Size : 0x%08X (%u bytes)\n",
           g_config.config.data.secure_storage_size, g_config.config.data.secure_storage_size);

    printf("\nStructure Sizes:\n");
    printf("  sizeof(g_config)=%zu bytes\n", sizeof(g_config));
    printf("  sizeof(config)=%zu bytes\n", sizeof(g_config.config));
    printf("  sizeof(header)=%zu bytes\n", sizeof(g_config.config.header));
    printf("  sizeof(data)=%zu bytes\n", sizeof(g_config.config.data));
}


/**
 * @brief Validate TrustZone configuration
 * @return 0 if valid, -1 if invalid
 */
static int validate_config()
{
    // Check signature
    if (g_config.signature != TRUSTZONE_CONFIG_SIGNATURE) {
        printf("Error: Invalid signature 0x%08X, expected 0x%08X\n",
               g_config.signature, TRUSTZONE_CONFIG_SIGNATURE);
        return -1;
    }

    // Check version
    if (g_config.version_major != TRUSTZONE_CONFIG_VERSION_MAJOR ||
        g_config.version_minor != TRUSTZONE_CONFIG_VERSION_MINOR) {
        printf("Error: Invalid version %u.%u, expected %u.%u\n",
               g_config.version_major, g_config.version_minor,
               TRUSTZONE_CONFIG_VERSION_MAJOR, TRUSTZONE_CONFIG_VERSION_MINOR);
        return -1;
    }

    // Check header version
    if (g_config.config.header.version_id != TRUSTZONE_CONFIG_VERSION_MAJOR) {
        printf("Error: Invalid header version 0x%02X, expected 0x%02X\n",
               g_config.config.header.version_id, TRUSTZONE_CONFIG_VERSION_MAJOR);
        return -1;
    }

    // Check header length
    uint32_t expected_header_length = sizeof(trustzone_export_config_t);
    if (g_config.config.header.length != expected_header_length) {
        printf("Error: Invalid header length %u, expected %u\n",
               g_config.config.header.length, expected_header_length);
        return -1;
    }

    // Check secure storage type
    if (g_config.config.data.secure_storage_type >= SEC_STORAGE_TYPE_INVALID) {
        printf("Error: Invalid secure storage type 0x%02X\n",
               g_config.config.data.secure_storage_type);
        return -1;
    }


    return 0;
}

int main(int argc, char **argv)
{
    uint64_t checksum = 0ULL;
    char bin_name[256] = {0};
    FILE *bin_file = NULL;

    // Parse mode: read and display existing configuration
    if (argc > 1) {
        printf("Parsing TrustZone configuration from %s...\n", argv[1]);

        bin_file = fopen(argv[1], "rb");
        if (bin_file == NULL) {
            printf("Error: Failed to open file %s: %s\n", argv[1], strerror(errno));
            return -1;
        }

        size_t read_len = fread(&g_config, sizeof(g_config), 1, bin_file);
        fclose(bin_file);

        if (read_len != 1) {
            printf("Error: Failed to read configuration (read %zu of 1 objects)\n", read_len);
            return -1;
        }

        printf("Successfully read %zu bytes\n\n", sizeof(g_config));

        // Validate configuration
        if (validate_config() != 0) {
            printf("Configuration validation failed!\n");
            return -1;
        }

        // Verify checksum
        if (!double_check_sum(&g_config, sizeof(g_config), &checksum, true)) {
            printf("Warning: Checksum verification failed!\n");
        } else {
            printf("Checksum verification passed\n");
        }

        dump_config();
        return 0;
    }

    // Generate mode: create new configuration
    printf("Generating TrustZone configuration...\n");

    // Initialize configuration with 0xFF
    memset(&g_config, 0xFF, sizeof(g_config));

    // Set version information
    g_config.version_major = TRUSTZONE_CONFIG_VERSION_MAJOR;
    g_config.version_minor = TRUSTZONE_CONFIG_VERSION_MINOR;
    g_config.timestamp = (uint32_t)(time(NULL) - CixEpoch());
    g_config.length = sizeof(trustzone_export_config_crc_t);
    g_config.signature = TRUSTZONE_CONFIG_SIGNATURE;
    g_config.crc1 = g_config.crc2 = 0;

#if TRUSTZONE_CONFIG_ENABLE
    // Copy configuration from user_config.h
    memcpy(&g_config.config, &trustzone_config, sizeof(trustzone_config));
#else
    printf("Warning: TrustZone configuration is disabled (TRUSTZONE_CONFIG_ENABLE=0)\n");
    // Create minimal valid configuration
    g_config.config.header.version_id = TRUSTZONE_CONFIG_VERSION_MAJOR;
    g_config.config.header.length = sizeof(trustzone_export_config_t);
    g_config.config.data.spe_feature_en = 0x00;  // Disabled
    g_config.config.data.secure_storage_type = SEC_STORAGE_TYPE_NOF_DISABLED;
    g_config.config.data.secure_storage_addr = 0x00000000;
    g_config.config.data.secure_storage_size = 0x00000000;
#endif

    // Validate configuration before generating checksum
    if (validate_config() != 0) {
        printf("Error: Configuration validation failed during generation!\n");
        return -1;
    }

    // Calculate checksum
    if (!double_check_sum(&g_config, sizeof(g_config), &checksum, false)) {
        printf("Error: Failed to calculate checksum!\n");
        return -1;
    }
    g_config.crc1 = checksum >> 32;
    g_config.crc2 = (uint32_t)(checksum & 0xFFFFFFFFULL);

    // Display configuration
    dump_config();

    // Write to binary file
    strcpy(bin_name, PROJECT_NAME);
    strcat(bin_name, "_config.bin");
    printf("\nGenerating binary file: %s\n", bin_name);

    bin_file = fopen(bin_name, "wb");
    if (bin_file == NULL) {
        printf("Error: Failed to create file %s: %s\n", bin_name, strerror(errno));
        return -1;
    }

    // Write configuration
    size_t write_len = fwrite(&g_config, sizeof(g_config), 1, bin_file);
    if (write_len != 1) {
        printf("Error: Failed to write configuration (wrote %zu of 1 objects)\n", write_len);
        fclose(bin_file);
        return -1;
    }

    // Pad file to 4KB with 0xFF
    assert(sizeof(g_config) <= TRUSTZONE_CONFIG_BIN_SIZE);
    size_t remaining_bytes = TRUSTZONE_CONFIG_BIN_SIZE - sizeof(g_config);

    if (remaining_bytes > 0) {
        uint8_t *padding = malloc(remaining_bytes);
        if (padding == NULL) {
            printf("Error: Failed to allocate memory for padding\n");
            fclose(bin_file);
            return -1;
        }

        memset(padding, 0xFF, remaining_bytes);
        write_len = fwrite(padding, remaining_bytes, 1, bin_file);
        free(padding);

        if (write_len != 1) {
            printf("Error: Failed to write padding (wrote %zu of 1 objects)\n", write_len);
            fclose(bin_file);
            return -1;
        }
    }

    fclose(bin_file);

    printf("Successfully wrote %u bytes to %s\n", TRUSTZONE_CONFIG_BIN_SIZE, bin_name);
    printf("TrustZone configuration generation completed successfully!\n");

    return 0;
}