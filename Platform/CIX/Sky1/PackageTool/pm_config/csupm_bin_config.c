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

#include "pm_export_config.h"

#include "opp_config_custom.h"
#include "user_config.h"

#define PM_CONFIG_BIN_SIZE  (4096)

#define ARRAY_LENGTH(_a)    (sizeof(_a) / sizeof(_a[0]))

#define PROJECT_NAME    "csu_pm"
#define VALID           (0)
#define INVALID         (1)
pm_export_config_crc_t g_config;

_Static_assert(((sizeof(g_config) - sizeof(g_config.crc1) - sizeof(g_config.crc2)) & 0x3) == 0,
    "PM config block size must be 4-byte aligned!");

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

#if BIOS_OPP_TABLE_CONFIG
static uint32_t volt_abs(uint32_t a, uint32_t b)
{
    if (a >= b) {
        return a - b;
    } else {
        return b - a;
    }
}

static bool check_opp_table(void)
{
    domain_opp_config_t *config;
    uint32_t dsu_sust_freq;
    uint32_t dsu_sust_volt;
    size_t i;

    /* sustained index */
    for (i = 0; i < ARRAY_LENGTH(dom_opps); i++) {
        config = dom_opps[i];
        if (!config) {
            continue;
        }
        if (config->sustained_idx >= config->size) {
            printf("domain %zu: Bad sustained index %u; Must be lower than size %u\n",
                i, config->sustained_idx, config->size);
            return false;
        }
        if (config->size > DOMAIN_MAX_OPP_ENTRIES) {
            printf("domain %zu: OPP table too large. Must be smaller than %u\n",
                i, config->size);
            return false;
        }
    }

    /* DSU */
    config = dom_opps[DVFS_ELEMENT_IDX_DSU];
    if (!config) {
        printf("DSU domain OPP mising\n");
        return false;
    }

    dsu_sust_freq = config->opp_table[config->sustained_idx].frequency;
    dsu_sust_volt = config->opp_table[config->sustained_idx].voltage;

    for (i = 0; i < ARRAY_LENGTH(dom_opps); i++) {
        uint32_t freq;
        uint32_t volt;

        if (i < DVFS_ELEMENT_IDX_LITTLE || i > DVFS_ELEMENT_IDX_MID_G1) {
            continue;
        }
        config = dom_opps[i];
        freq = config->opp_table[config->sustained_idx].frequency;
        volt = config->opp_table[config->sustained_idx].voltage;

        if (volt_abs(volt, dsu_sust_volt) > 200) {
            printf("domain %zu: Bad sustained voltage %u.\n", i, volt);
            return false;
        }
        if (freq / 2 > dsu_sust_freq) {
            printf("domain %zu: Bad frequency %u. Too large\n", i, freq);
            return false;
        }
    }

    return true;
}
#endif

static void dump_pmic_config(pm_config_pmic_t* config)
{
    char tmpbuf[16];
    size_t i;

    printf("\tpmic scheme: %u, valid: %s\n", config->pmic_scheme.fields.raw_data, (PM_CONFIG_VALID == config->pmic_scheme.fields.valid) ? "yes" : "no");
    if (PM_CONFIG_VALID != config->pmic_scheme.fields.valid ||
        CONFIG_EDP_CFG_CUSTOM != config->pmic_scheme.fields.raw_data) {
        /* print pmic setting only for CUSTOM */
        return;
    }

    printf("\tmargin:\n");
    printf("\topp_max:");

    for (i = 0; i < ARRAY_LENGTH(config->opp_max); i++) {
        sprintf(tmpbuf, "%u, ", config->opp_max[i]);
        printf("%s", tmpbuf);
    }
    printf("\n");
    printf("\tedp_cfg:\n");

    for (i = 0; i < OPP_PWR_RAIL_MAX; i++) {
        DPM_PWR_RAIL_CFG edp_cfg;
        memcpy(&edp_cfg, config->edp[i], sizeof(edp_cfg));
        printf("\t\tEDP %zu: vr_type %u, pwr_cap %u, i2c_port %u, i2c_addr 0x%02x, i2c_buck %u, vboot_mV %u, delta_mV %u\n",
            i, edp_cfg.vr_type, edp_cfg.pwr_cap, edp_cfg.i2c_port, edp_cfg.i2c_addr,
            edp_cfg.i2c_buck, edp_cfg.vboot_mV, edp_cfg.delta_mV);
    }
}

static void dump_opp_config(domain_opp_config_t *config)
{
    unsigned int i;
    uint16_t j;

    for (i = 0; i < DOMAIN_MAX_COUNT; i++) {
        if (config->size == 0xFFFF) {
            continue;
        }
        printf("domain %u\n", i);
        for (j = 0; j < config->size; j++) {
            printf(" %s opp %u: level %u, freq(kHz) %u, volt(mV) %u, pwr(mW/mV) %u\n",
                j == config->sustained_idx ? "*" : " ", j,
                config->opp_table[j].level, config->opp_table[j].frequency,
                config->opp_table[j].voltage, config->opp_table[j].power);
        }
        printf("\n");
        config++;
    }
}

static void dump_config()
{
    pm_export_config_t *config = &g_config.config;

    printf("sizeof(g_config)=%zu, sizeof(opps)=%zu\n", sizeof(g_config), sizeof(config->opps));

    printf("version:%u.%u\n", config->version_major, config->version_minor);
    printf("timestamp:%u\n", config->timestamp);
    printf("pmic config:\n");
    dump_pmic_config(&config->pmic_config);

    printf("OPP config\n");
    dump_opp_config(config->opps);

    printf("crc check: cka:0x%08x, ckb:0x%08x\n", g_config.crc1, g_config.crc2);
}

int main(int argc, char **argv)
{
    uint64_t ck = 0ULL;
    char bin_name[256] = {0};
    FILE* bin_file = NULL;
    pm_export_config_t* config = &g_config.config;

    memset(&g_config, 0xff, sizeof(g_config));

    // version & timestamp
    config->version_major = 1;
    config->version_minor = 0;
    config->timestamp = (uint32_t)time(NULL);

    //pmic config:
    memcpy(&config->pmic_config, &pmic_config, PMIC_CONFIG_SIZE);

    //fan config
    memcpy(config->fan_config,   fan_config,   FAN_CONFIG_SIZE);

    //opp table config
#if BIOS_OPP_TABLE_CONFIG
    if (!check_opp_table()) {
        printf("Bad OPP table\n");
        return -1;
    }

    config->opp_valid = BIOS_CONFIG_VALID;

    for (size_t i = 0; i < ARRAY_LENGTH(dom_opps); i++) {
        if (dom_opps[i]) {
            memcpy(&config->opps[i], dom_opps[i], sizeof(config->opps[i]));
        } else {
            memset(&config->opps[i], 0x00, sizeof(config->opps[i]));
        }
    }
#endif

    // checksum
    (void)double_check_sum(&g_config, sizeof(g_config) - 8, &ck, false);
    g_config.crc1 = ck >> 32;
    g_config.crc2 = (uint32_t)(ck & (0xFFFFFFFFull));

    dump_config();

    // write to file
    strcpy(bin_name, PROJECT_NAME);
    strcat(bin_name, "_config.bin");
    printf("generate file [%s]\n", bin_name);
    if ((bin_file = fopen(bin_name, "w+")) == NULL) {
      printf("file %s open failed!\n", bin_name);
      exit(-1);
    }
    size_t wr_len = fwrite(&g_config, sizeof(g_config), 1, bin_file);
    if (1 != wr_len) {
        printf("write length error!!, write %zu objects, expect %zu objects\n", wr_len, (size_t)1);
        fclose(bin_file);
        exit(-1);
    }

    // stuff 0xFF up to 4KB
    assert(sizeof(g_config) <= PM_CONFIG_BIN_SIZE);
    size_t remain = PM_CONFIG_BIN_SIZE - sizeof(g_config);
    uint8_t *remain_b;
    remain_b = malloc(remain);
    assert(remain_b != NULL);
    memset(remain_b, 0xFF, remain);
    wr_len = fwrite(remain_b, remain, 1, bin_file);
    free(remain_b);
    if (1 != wr_len) {
        printf("write 0xFF error!!\n");
        fclose(bin_file);
        exit(-1);
    }

    printf("write %u Bytes to file %s\n", PM_CONFIG_BIN_SIZE, bin_name);
    fclose(bin_file);
    return 0;
}
