/*
 * Copyright 2024 - Cix Technology Group Co., Ltd. All Rights Reserved.
 */
#ifndef __PMIC_CONFIG_H__
#define __PMIC_CONFIG_H__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "pm_export_config.h"
#include "cfg_dpm_pwrrail.h"

#pragma pack(push, 1)

#define OPP_DXS_MAX         13
#define OPP_PWR_RAIL_MAX    8
typedef struct {
    config_data_t       pmic_scheme;
    uint16_t            opp_max[OPP_DXS_MAX];
    DPM_PWR_RAIL_CFG    edp_cfg[OPP_PWR_RAIL_MAX];
} shadow_pm_config_pmic_t;

typedef struct {
    rpm_entry_t  rpm_table[FAN_MODE_MAX][MAX_FAN_TABLE_ENTRIES]; //rpm, up_temp, down_temp
    uint8_t rpm_table_items[FAN_MODE_MAX];
    uint8_t rpm_table_valid[FAN_MODE_MAX]; //0:valid, others:invalid
    config_data_t fan_id;
    config_data_t fan_polarity;
    config_data_t scaleup_margin;
    config_data_t pwm_freq;
} shadow_pm_config_fan_t;

#pragma pack(pop)

static shadow_pm_config_pmic_t pmic_config = {
	.pmic_scheme = {
		.fields = {
            .valid = PM_CONFIG_VALID,
            .raw_data = CONFIG_EDP_CFG_CUSTOM,
        },
	},
       /* Fmax of lit,  gm0,  gm1,  gb0,  gb1,  dsu,  g_t,  g_c,   ci,   mm,  vpu,  npu,  mem */
    .opp_max = { 4000, 4000, 4000, 4000, 4000, 4000, 4000, 4000, 4000, 4000, 4000, 4000, 4000 },
    .edp_cfg = {
        [DPM_EDP_CPU_LIT] = { .vr_type = VR_MP2845, .pwr_cap =  2500, .i2c_port = 0, .i2c_addr = 0x45, .i2c_buck = 1, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_CPU_GM0] = { .vr_type = VR_MP2845, .pwr_cap =  6500, .i2c_port = 1, .i2c_addr = 0x45, .i2c_buck = 2, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_CPU_GM1] = { .vr_type = VR_MP2845, .pwr_cap =  6500, .i2c_port = 0, .i2c_addr = 0x45, .i2c_buck = 0, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_CPU_GB0] = { .vr_type = VR_MP2845, .pwr_cap =  8000, .i2c_port = 0, .i2c_addr = 0x45, .i2c_buck = 2, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_CPU_GB1] = { .vr_type = VR_MP2845, .pwr_cap =  8000, .i2c_port = 0, .i2c_addr = 0x45, .i2c_buck = 3, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_DSU]     = { .vr_type = VR_MP2845, .pwr_cap =  5500, .i2c_port = 1, .i2c_addr = 0x45, .i2c_buck = 3, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_GPU]     = { .vr_type = VR_MP2845, .pwr_cap = 12000, .i2c_port = 1, .i2c_addr = 0x45, .i2c_buck = 1, .vboot_mV = 750, .delta_mV = 0 },
        [DPM_EDP_SOC]     = { .vr_type = VR_MP2845, .pwr_cap =  9000, .i2c_port = 1, .i2c_addr = 0x45, .i2c_buck = 0, .vboot_mV = 750, .delta_mV = 0 },
    },
};

#define PMIC_CONFIG_OFFSET	12
#define PMIC_CONFIG_SIZE    sizeof(pmic_config)

static shadow_pm_config_fan_t fan_config[MAX_FAN_NUM] = {
	[0] = {
        .rpm_table[FAN_MODE_NORMAL] =
              /* RPM       temp        temp
               *           increase    decrease */
            {   {0,         0,          20},
                {1100,      40,         25},
                {1600,      50,         46},
                {2700,      60,         56},
                {4100,      65,         62},
                {5500,      72,         67},
            },
        .rpm_table[FAN_MODE_PERFORMANCE] =
            {   {0,         0,          20},
                {2700,      60,         56},
                {4100,      65,         62},
                {5500,      72,         67},
            },
        .rpm_table[FAN_MODE_QUIET] =
            {   {0,         0,          20},
                {1100,      40,         25},
                {1600,      50,         46},
                {2700,      60,         56},
            },
        .rpm_table_items    = {6, 4, 4}, /* table size of NORMAL/PERF/QUIET respectively */
        .rpm_table_valid    = {1, 1, 1}, /* table valid bit of NORMAL/PERF/QUIET respectively */
        .fan_id   ={ .fields = {
                        .valid = PM_CONFIG_VALID,
                        .raw_data = 0,
                    }
        },
        .fan_polarity   ={ .fields = {
                        .valid = PM_CONFIG_VALID,
                        .raw_data = 2,
                    }
        },
        .scaleup_margin   ={ .fields = {
                        .valid = PM_CONFIG_VALID,
                        .raw_data = 500,
                    }
        },
        .pwm_freq  ={ .fields = {
                        .valid = PM_CONFIG_VALID,
                        .raw_data = 100,
                    }
        }

    }
};

#define FAN_CONFIG_SIZE    sizeof(fan_config)

#endif
