#ifndef MAGNETRON_H
#define MAGNETRON_H

typedef enum _PowerSetting {
    POWER_MAX,
    POWER_HALF,
    POWER_QUARTER,
    POWER_OFF
} PowerSetting;

void setMagnetronPower(PowerSetting power);

#endif