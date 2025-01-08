/*
 * Copyright 2024 - Cix Technology Group Co., Ltd. All Rights Reserved.
 */
#ifndef __OPP_CONFIG_H__
#define __OPP_CONFIG_H__

#include "pm_export_config.h"
#include "opp_config.h"

#define BIOS_OPP_TABLE_CONFIG   0

#if BIOS_OPP_TABLE_CONFIG
/* V1.1, DFS */
static domain_opp_config_t dxs_gc = {
    .size = 3,
    .sustained_idx = 2,
    .opp_table = {
        [0] = { .level = 200, .frequency = 200000, .voltage = 790, .power = 790 },
        [1] = { .level = 350, .frequency = 350000, .voltage = 790, .power = 790 },
        [2] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 790 },  /* sustained */
    },
};

static domain_opp_config_t dxs_gt = {
    .size = 3,
    .sustained_idx = 1,
    .opp_table = {
        [0] = { .level = 200, .frequency = 200000, .voltage = 790, .power = 790 },
        [1] = { .level = 350, .frequency = 350000, .voltage = 790, .power = 790 },  /* sustained */
        [2] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 790 },
    },
};

static domain_opp_config_t dxs_lit = {
    .size = 5,
    .sustained_idx = 4,
    .opp_table = {
        [0] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 526 },
        [1] = { .level = 1000, .frequency = 1000000, .voltage = 790, .power = 744 },
        [2] = { .level = 1200, .frequency = 1200000, .voltage = 790, .power = 969 },
        [3] = { .level = 1400, .frequency = 1400000, .voltage = 790, .power = 1226 },
        [4] = { .level = 1600, .frequency = 1600000, .voltage = 790, .power = 1514 },   /* sustained */
    },
};

static domain_opp_config_t dxs_gb0 = {
    .size = 6,
    .sustained_idx = 5,
    .opp_table = {
        [0] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 610 },
        [1] = { .level = 1000, .frequency = 1000000, .voltage = 790, .power = 845 },
        [2] = { .level = 1200, .frequency = 1200000, .voltage = 790, .power = 1086 },
        [3] = { .level = 1400, .frequency = 1400000, .voltage = 790, .power = 1356 },
        [4] = { .level = 1600, .frequency = 1600000, .voltage = 790, .power = 1656 },
        [5] = { .level = 1800, .frequency = 1800000, .voltage = 790, .power = 1986 },   /* sustained */
    },
};

static domain_opp_config_t dxs_gb1 = {
    .size = 8,
    .sustained_idx = 7,
    .opp_table = {
        [0] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 610 },
        [1] = { .level = 1000, .frequency = 1000000, .voltage = 790, .power = 823 },
        [2] = { .level = 1200, .frequency = 1200000, .voltage = 790, .power = 1033 },
        [3] = { .level = 1400, .frequency = 1400000, .voltage = 790, .power = 1265 },
        [4] = { .level = 1600, .frequency = 1600000, .voltage = 790, .power = 1517 },
        [5] = { .level = 1800, .frequency = 1800000, .voltage = 790, .power = 1791 },
        [6] = { .level = 2000, .frequency = 2000000, .voltage = 790, .power = 2087 },
        [7] = { .level = 2200, .frequency = 2200000, .voltage = 790, .power = 2403 },   /* sustained */
    },
};

static domain_opp_config_t dxs_gm0 = {
    .size = 7,
    .sustained_idx = 6,
    .opp_table = {
        [0] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 582 },
        [1] = { .level = 1000, .frequency = 1000000, .voltage = 790, .power = 794 },
        [2] = { .level = 1200, .frequency = 1200000, .voltage = 790, .power = 1005 },
        [3] = { .level = 1400, .frequency = 1400000, .voltage = 790, .power = 1240 },
        [4] = { .level = 1600, .frequency = 1600000, .voltage = 790, .power = 1498 },
        [5] = { .level = 1800, .frequency = 1800000, .voltage = 790, .power = 1780 },
        [6] = { .level = 2000, .frequency = 2000000, .voltage = 790, .power = 2085 },   /* sustained */
    },
};

static domain_opp_config_t dxs_gm1 = {
    .size = 5,
    .sustained_idx = 4,
    .opp_table = {
        [0] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 582 },
        [1] = { .level = 1000, .frequency = 1000000, .voltage = 790, .power = 824 },
        [2] = { .level = 1200, .frequency = 1200000, .voltage = 790, .power = 1078 },
        [3] = { .level = 1400, .frequency = 1400000, .voltage = 790, .power = 1366 },
        [4] = { .level = 1600, .frequency = 1600000, .voltage = 790, .power = 1690 },   /* sustained */
    },
};

static domain_opp_config_t dxs_dsu = {
    .size = 5,
    .sustained_idx = 4,
    .opp_table = {
        [0] = { .level = 500, .frequency = 700000, .voltage = 790, .power = 1931 },
        [1] = { .level = 700, .frequency = 700000, .voltage = 790, .power = 3686 },
        [2] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 4045 },
        [3] = { .level = 900, .frequency = 900000, .voltage = 790, .power = 4403 },
        [4] = { .level = 1100, .frequency = 1100000, .voltage = 790, .power = 5120 },   /* sustained */
    },
};

static domain_opp_config_t dxs_npu = {
    .size = 3,
    .sustained_idx = 2,
    .opp_table = {
        [0] = { .level = 400, .frequency = 400000, .voltage = 790, .power = 361 },
        [1] = { .level = 600, .frequency = 600000, .voltage = 790, .power = 539 },
        [2] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 1149 }, /* sustained */
    },
};

static domain_opp_config_t dxs_vpu = {
    .size = 3,
    .sustained_idx = 2,
    .opp_table = {
        [0] = { .level = 400, .frequency = 300000, .voltage = 790, .power = 303 },  /* sustained */
        [1] = { .level = 600, .frequency = 600000, .voltage = 790, .power = 539 },
        [2] = { .level = 800, .frequency = 800000, .voltage = 790, .power = 1149 },
    },
};

static domain_opp_config_t dxs_ci = {
    .size = 2,
    .sustained_idx = 1,
    .opp_table = {
        [0] = { .level = 500, .frequency = 500000, .voltage = 790, .power = 426 },
        [1] = { .level = 1000, .frequency = 1000000, .voltage = 790, .power = 1966 },   /* sustained */
    },
};

static domain_opp_config_t dxs_mm = {
    .size = 3,
    .sustained_idx = 2,
    .opp_table = {
        [0] = { .level = 375, .frequency = 375000, .voltage = 790, .power = 346 },
        [1] = { .level = 600, .frequency = 600000, .voltage = 790, .power = 539 },
        [2] = { .level = 750, .frequency = 750000, .voltage = 790, .power = 993 },  /* sustained */
    },
};

static domain_opp_config_t *dom_opps[DVFS_ELEMENT_IDX_COUNT] = {
    [DVFS_ELEMENT_IDX_GPU_CORE] = &dxs_gc,
    [DVFS_ELEMENT_IDX_GPU_TOP] = &dxs_gt,
    [DVFS_ELEMENT_IDX_LITTLE] = &dxs_lit,
    [DVFS_ELEMENT_IDX_BIG_G0] = &dxs_gb0,
    [DVFS_ELEMENT_IDX_BIG_G1] = &dxs_gb1,
    [DVFS_ELEMENT_IDX_MID_G0] = &dxs_gm0,
    [DVFS_ELEMENT_IDX_MID_G1] = &dxs_gm1,
    [DVFS_ELEMENT_IDX_DSU] = &dxs_dsu,
    [DVFS_ELEMENT_IDX_NPU] = &dxs_npu,
    [DVFS_ELEMENT_IDX_VPU] = &dxs_vpu,
    [DVFS_ELEMENT_IDX_CI700] = &dxs_ci,
    [DVFS_ELEMENT_IDX_MMHUB] = &dxs_mm,
};
#endif

#endif
