/*
 * Copyright 2024 - Cix Technology Group Co., Ltd. All Rights Reserved.
 */
#ifndef __PM_EXPORT_CONFIG_H__
#define __PM_EXPORT_CONFIG_H__

#include <stdint.h>

#pragma pack(push, 1)

/* basics */
typedef union {
    uint32_t data;
    struct {
        /*0: valid, 1: invalid*/
#define PM_CONFIG_VALID       0
#define PM_CONFIG_INVALID     1
        uint32_t valid      :   1;
        uint32_t raw_data   :   31;
    } fields;
} config_data_t;

/* PMIC */
#define OPP_DXS_MAX         13
#define OPP_PWR_RAIL_MAX    8
typedef struct {
    config_data_t   pmic_scheme;
    uint16_t        opp_max[OPP_DXS_MAX];
    uint32_t        edp[OPP_PWR_RAIL_MAX][2];
} pm_config_pmic_t;

#define MAX_FAN_NUM (2)
#define MAX_FAN_TABLE_ENTRIES (9)
typedef enum {
    FAN_MODE_NORMAL = 0,
    FAN_MODE_PERFORMANCE,
    FAN_MODE_QUIET,
    FAN_MODE_MAX
} fan_mode_t;

typedef struct {
    uint16_t rpm;
    int8_t up_temp;
    int8_t down_temp;
} rpm_entry_t;

typedef struct fan_dev_config {
    rpm_entry_t rpm_table[FAN_MODE_MAX][MAX_FAN_TABLE_ENTRIES];
    uint8_t rpm_table_items[FAN_MODE_MAX];
    uint8_t rpm_table_valid[FAN_MODE_MAX]; //0:valid, others:invalid
    config_data_t fan_id;
    config_data_t fan_polarity;
    config_data_t scaleup_margin;
    config_data_t pwm_freq;
} fan_dev_config_t;

/* OPP table */
#define DOMAIN_MAX_OPP_ENTRIES  13
#define DOMAIN_MAX_COUNT        13

typedef struct dvfs_opp {
    uint32_t    level;      /*!< Level value of the OPP */
    uint32_t    voltage;    /*!< Power supply voltage in millivolts (mV) */
    uint32_t    frequency;  /*!< Clock rate in Hertz (Hz) */
    uint32_t    power;      /*!< Power draw in milliwatts (mW) */
} dvfs_opp_t;

typedef struct domain_opp_config {
    uint16_t	size;
    uint16_t    sustained_idx;
    dvfs_opp_t  opp_table[DOMAIN_MAX_OPP_ENTRIES];
} domain_opp_config_t;

typedef struct {
    uint32_t                version_major;
    uint32_t                version_minor;
    uint32_t                timestamp;
    pm_config_pmic_t        pmic_config;
    fan_dev_config_t        fan_config[MAX_FAN_NUM];
    uint8_t                 _internal[387];
    uint8_t                 opp_valid;
    domain_opp_config_t     opps[DOMAIN_MAX_COUNT];
} pm_export_config_t;

typedef struct {
    pm_export_config_t config;
    uint8_t                 padding[2];
    /* undertermined position */
    uint32_t                crc1;
    uint32_t                crc2;
} pm_export_config_crc_t;

#pragma pack(pop)

#endif
