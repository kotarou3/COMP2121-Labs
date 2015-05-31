#ifndef MAGNETRON_H
#define MAGNETRON_H

#ifndef __ASSEMBLER__

typedef enum _PowerSetting {
    POWER_MAX,
    POWER_HALF,
    POWER_QUARTER,
    POWER_OFF
} PowerSetting;

void magnetronSetup();
void magnetronSetPower(PowerSetting power);

#else

#define POWER_MAX 0
#define POWER_HALF (POWER_MAX + 1)
#define POWER_QUARTER (POWER_HALF + 1)
#define POWER_OFF (POWER_QUARTER + 1)
#define sizeof_PowerSetting 1

#endif

#endif
