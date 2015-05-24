#include <avr/io.h>
#include "circular-buffer.h"
#include "util.h"

#define HOLES_PER_REVOLUTION 4
#define MAX_RPS 100
#define RPS_SAMPLE_SIZE 4

#define CHECK_RPS_INTERVAL 250

#define PWM_HALF_PERIOD 1000 // In clock cycles (= TOP)
#define MIN_DUTY_CYCLE_STEP_INTERVAL 10
#define MAX_DUTY_CYCLE_STEP_INTERVAL 100

#define RPS_DETECTOR(reg) reg##D
#define RPS_DETECTOR_BIT PD2
#define RPS_DETECTOR_INT(reg) reg##2
#define RPS_DETECTOR_INT_S(reg, suf) reg##2##suf
#define RPS_DETECTOR_TIMER(reg) reg##4
#define RPS_DETECTOR_TIMER_S(reg, suf) reg##4##suf
#define RPS_DETECTOR_TICKS_PER_SECOND (F_CPU / 1024)

#define PWM_OUTPUT(reg) reg##E
#define PWM_OUTPUT_BIT PE4
#define PWM_TIMER(reg) reg##3
#define PWM_TIMER_S(reg, suf) reg##3##suf

// static CircularBuffer rpsBuffer;
.lcomm rpsBuffer, sizeof_CircularBuffer
// static uint8_t rpsRawBuffer[RPS_SAMPLE_SIZE];
.lcomm rpsRawBuffer, RPS_SAMPLE_SIZE

// static uint8_t targetRps;
.lcomm targetRps, 1
// static uint16_t topDutyCycle;
.lcomm topDutyCycle, 2
// static uint16_t bottomDutyCycle;
.lcomm bottomDutyCycle, 2

// uint8_t motorGetRps() {
    .global motorGetRps
motorGetRps:

    // uint16_t rpsSum = 0;
    clr r24
    clr r25

    // for (uint8_t i = 0; i < RPS_SAMPLE_SIZE; ++i)
    //     rpsSum += rpsRawBuffer[i];
    ldi XL, lo8(rpsRawBuffer)
    ldi XH, hi8(rpsRawBuffer)
    ldi r23, hi8(rpsRawBuffer + RPS_SAMPLE_SIZE)
motorGetRps_nextValue:
    ld r22, X+
    add r24, r22
    adc r25, r1
    cpi XL, lo8(rpsRawBuffer + RPS_SAMPLE_SIZE)
    cpc XH, r23
    brlo motorGetRps_nextValue

    // return rpsSum / RPS_SAMPLE_SIZE;
    lsr r25
    ror r24
    lsr r25
    ror r24
    ret
// }

// static void onDetectorFallingEdge() {
onDetectorFallingEdge:

    // static uint16_t lastTick;
    .lcomm onDetectorFallingEdge_lastTick, 2

    // uint16_t now = RPS_DETECTOR_TIMER(TCNT);
    lds r22, _SFR_MEM_ADDR(RPS_DETECTOR_TIMER_S(TCNT, L))
    lds r23, _SFR_MEM_ADDR(RPS_DETECTOR_TIMER_S(TCNT, H))

    // uint16_t delta_t = now - lastTick;
    movw r24, r22
    lds r20, onDetectorFallingEdge_lastTick
    lds r21, onDetectorFallingEdge_lastTick + 1
    sub r22, r20
    sbc r23, r21

    // lastTick = now;
    sts onDetectorFallingEdge_lastTick, r24
    sts onDetectorFallingEdge_lastTick + 1, r25

    // Given a known max rps, there is a minimum delta_t
    // If the delta_t we get is lower than that minimum, discard the result
    // if (delta_t < RPS_DETECTOR_TICKS_PER_SECOND / (HOLES_PER_REVOLUTION * MAX_RPS))
    //     return;
    ldi r25, hi8(RPS_DETECTOR_TICKS_PER_SECOND / (HOLES_PER_REVOLUTION * MAX_RPS))
    cpi r22, lo8(RPS_DETECTOR_TICKS_PER_SECOND / (HOLES_PER_REVOLUTION * MAX_RPS))
    cpc r23, r25
    skipIf sh
    ret

    // uint8_t rps = udivmod16(RPS_DETECTOR_TICKS_PER_SECOND, delta_t * HOLES_PER_REVOLUTION);
    lsl r22
    rol r23
    lsl r22
    rol r23
    ldi r24, lo8(RPS_DETECTOR_TICKS_PER_SECOND)
    ldi r25, hi8(RPS_DETECTOR_TICKS_PER_SECOND)
    call udivmod16

    // CircularBuffer_pushBack(&rpsBuffer, rps);
    ldi r24, lo8(rpsBuffer)
    ldi r25, hi8(rpsBuffer)
    jmp CircularBuffer_pushBack

// }

// static void checkRps() {
checkRps:

    // static uint16_t stepInterval;
    .lcomm checkRps_stepInterval, 2

    // if (stepInterval == 0)
    lds r24, checkRps_stepInterval
    lds r25, checkRps_stepInterval + 1
    or r24, r25
    brnz checkRps_stepInterval_notZero

    //     stepInterval = MIN_DUTY_CYCLE_STEP_INTERVAL;
    ldi r24, lo8(MIN_DUTY_CYCLE_STEP_INTERVAL)
    ldi r25, hi8(MIN_DUTY_CYCLE_STEP_INTERVAL)
    sts checkRps_stepInterval, r24
    sts checkRps_stepInterval + 1, r25

checkRps_stepInterval_notZero:
    // uint8_t rps = motorGetRps();
    call motorGetRps

    lds r25, targetRps
    // if (rps == targetRps)
    //     return;
    cp r24, r25
    skipIf ne
    ret

    // Starts searching for the correct duty cycle's bounds by doubling the
    // search interval each step, then binary searches within those bounds.
    // This is done so the change in motor speed isn't too abrupt.

    // uint16_t currentDutyCycle = PWM_TIMER(OCR, B);
    lds r20, _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL))
    lds r21, _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH))

    lds r18, topDutyCycle
    lds r19, topDutyCycle + 1
    lds r22, bottomDutyCycle
    lds r23, bottomDutyCycle + 1

    // if (rps < targetRps) {
    brsh checkRps_setLower

    //     if (topDutyCycle == currentDutyCycle) {
    cp r18, r20
    cpc r19, r21
    brne checkRps_setHigher_notAtCeiling

    //         bottomDutyCycle = currentDutyCycle;
    sts bottomDutyCycle, r20
    sts bottomDutyCycle + 1, r21

    lds r24, checkRps_stepInterval
    lds r25, checkRps_stepInterval + 1
    //         topDutyCycle += stepInterval;
    add r18, r24
    adc r19, r25

    //         stepInterval *= 2;
    lsl r24
    rol r25

    //         if (topDutyCycle > PWM_HALF_PERIOD)
    ldi r21, hi8(PWM_HALF_PERIOD + 1)
    cpi r18, lo8(PWM_HALF_PERIOD + 1)
    cpc r19, r21
    brlo checkRps_setHigher_notOverflowed

    //             topDutyCycle = PWM_HALF_PERIOD;
    ldi r18, lo8(PWM_HALF_PERIOD)
    ldi r19, hi8(PWM_HALF_PERIOD)

checkRps_setHigher_notOverflowed:
    //         if (stepInterval > MAX_DUTY_CYCLE_STEP_INTERVAL)
    ldi r21, hi8(MAX_DUTY_CYCLE_STEP_INTERVAL + 1)
    cpi r24, lo8(MAX_DUTY_CYCLE_STEP_INTERVAL + 1)
    cpc r25, r21
    brlo checkRps_setHigher_stepIntervalNotOverMax

    //             stepInterval = MAX_DUTY_CYCLE_STEP_INTERVAL;
    ldi r24, lo8(MAX_DUTY_CYCLE_STEP_INTERVAL)
    ldi r25, hi8(MAX_DUTY_CYCLE_STEP_INTERVAL)

checkRps_setHigher_stepIntervalNotOverMax:
    sts topDutyCycle, r18
    sts topDutyCycle + 1, r19
    sts checkRps_stepInterval, r24
    sts checkRps_stepInterval + 1, r25

    //         currentDutyCycle = topDutyCycle;
    movw r20, r18

    rjmp checkRps_updateDutyCycle

checkRps_setHigher_notAtCeiling:
    //     } else {
    //         bottomDutyCycle = currentDutyCycle + 1;
    subi r20, lo8(-1)
    sbci r21, hi8(-1)
    sts bottomDutyCycle, r20
    sts bottomDutyCycle + 1, r21

    //         currentDutyCycle = (bottomDutyCycle + topDutyCycle) / 2;
    add r20, r18
    adc r21, r19
    lsr r21
    ror r20

    //         stepInterval = 0;
    sts checkRps_stepInterval, r1
    sts checkRps_stepInterval + 1, r1

    rjmp checkRps_updateDutyCycle

    //     }
checkRps_setLower:
    // } else {
    //     if (bottomDutyCycle == currentDutyCycle) {
    cp r22, r20
    cpc r23, r21
    brne checkRps_setLower_notAtFloor

    lds r24, checkRps_stepInterval
    lds r25, checkRps_stepInterval + 1
    //         bottomDutyCycle -= stepInterval;
    sub r22, r24
    sbc r23, r25

    //         topDutyCycle = currentDutyCycle;
    sts topDutyCycle, r20
    sts topDutyCycle + 1, r21

    //         stepInterval *= 2;
    lsl r24
    rol r25

    //         if (bottomDutyCycle > PWM_HALF_PERIOD)
    ldi r21, hi8(PWM_HALF_PERIOD + 1)
    cpi r22, lo8(PWM_HALF_PERIOD + 1)
    cpc r23, r21
    brlo checkRps_setLower_notUnderflowed

    //             // Underflowed
    //             bottomDutyCycle = 0;
    clr r22
    clr r23

checkRps_setLower_notUnderflowed:
    //         if (stepInterval > MAX_DUTY_CYCLE_STEP_INTERVAL)
    ldi r21, hi8(MAX_DUTY_CYCLE_STEP_INTERVAL + 1)
    cpi r24, lo8(MAX_DUTY_CYCLE_STEP_INTERVAL + 1)
    cpc r25, r21
    brlo checkRps_setLower_stepIntervalNotOverMax

    //             stepInterval = MAX_DUTY_CYCLE_STEP_INTERVAL;
    ldi r24, lo8(MAX_DUTY_CYCLE_STEP_INTERVAL)
    ldi r25, hi8(MAX_DUTY_CYCLE_STEP_INTERVAL)

checkRps_setLower_stepIntervalNotOverMax:
    sts bottomDutyCycle, r22
    sts bottomDutyCycle + 1, r23
    sts checkRps_stepInterval, r24
    sts checkRps_stepInterval + 1, r25

    //         currentDutyCycle = bottomDutyCycle;
    movw r20, r22

    rjmp checkRps_updateDutyCycle

checkRps_setLower_notAtFloor:
    //     } else {
    //         topDutyCycle = currentDutyCycle;
    sts topDutyCycle, r20
    sts topDutyCycle + 1, r21

    //         currentDutyCycle = (bottomDutyCycle + topDutyCycle) / 2;
    add r20, r22
    adc r21, r23
    lsr r21
    ror r20

    //         stepInterval = 0;
    sts checkRps_stepInterval, r1
    sts checkRps_stepInterval + 1, r1

    //     }
    // }

checkRps_updateDutyCycle:
    // PWM_TIMER(OCR, B) = currentDutyCycle;
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH)), r21
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL)), r20

    ret
// }

// void motorSetRps(uint8_t rps) {
    .global motorSetRps
motorSetRps:

    // If the change in rps was large (> MAX_RPS / 2), use a linear estimate for the new duty cycle.
    // Otherwise, just let checkRps() adjust it normally.

    // if (rps > targetRps + MAX_RPS / 2 || rps + MAX_RPS / 2 < targetRps)
    lds r22, targetRps
    mov r23, r22
    subi r22, -(MAX_RPS / 2 + 1)
    cp r24, r22
    brsh motorSetRps_largeChange

    mov r25, r24
    subi r25, -(MAX_RPS / 2 + 1)
    cp r25, r23
    brsh motorSetRps_smallChange

motorSetRps_largeChange:
    //     topDutyCycle = bottomDutyCycle = PWM_TIMER(OCR, B) = rps * (PWM_HALF_PERIOD / MAX_RPS);
    ldi r22, PWM_HALF_PERIOD / MAX_RPS
    mul r24, r22
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH)), r1
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL)), r0
    clr r1

motorSetRps_smallChange:
    // else
    //     topDutyCycle = bottomDutyCycle = PWM_TIMER(OCR, B);
    lds r22, _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL))
    lds r23, _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH))
    sts topDutyCycle, r22
    sts topDutyCycle + 1, r23
    sts bottomDutyCycle, r22
    sts bottomDutyCycle + 1, r23

    // targetRps = rps;
    sts targetRps, r24

    ret
// }

// void motorSetup() {
    .global motorSetup
motorSetup:

    // CircularBuffer_init(&rpsBuffer, rpsRawBuffer, RPS_SAMPLE_SIZE, true);
    ldi r18, 1
    ldi r20, lo8(RPS_SAMPLE_SIZE)
    ldi r21, hi8(RPS_SAMPLE_SIZE)
    ldi r22, lo8(rpsRawBuffer)
    ldi r23, hi8(rpsRawBuffer)
    ldi r24, lo8(rpsBuffer)
    ldi r25, hi8(rpsBuffer)
    call CircularBuffer_init

    // RPS_DETECTOR(DDR) &= ~(1 << RPS_DETECTOR_BIT);
    // RPS_DETECTOR(PORT) |= 1 << RPS_DETECTOR_BIT;
    cbi _SFR_IO_ADDR(RPS_DETECTOR(DDR)), RPS_DETECTOR_BIT
    sbi _SFR_IO_ADDR(RPS_DETECTOR(PORT)), RPS_DETECTOR_BIT

    // Falling edge
    // EICRA |= 1 << RPS_DETECTOR_INT(ISC, 1);
    // EICRA &= ~(0 << RPS_DETECTOR_INT(ISC, 0));
    lds r24, _SFR_MEM_ADDR(EICRA)
    ori r24, 1 << RPS_DETECTOR_INT_S(ISC, 1)
    andi r24, ~(0 << RPS_DETECTOR_INT_S(ISC, 0))
    sts _SFR_MEM_ADDR(EICRA), r24

    // EIMSK |= 1 << RPS_DETECTOR_INT(INT);
    sbi _SFR_IO_ADDR(EIMSK), RPS_DETECTOR_INT(INT)

    // Setup PWM timer in phase/frequency correct mode, with no prescaler
    // Clear/Set output on OCRnB compare match when up/down-counting
    // PWM_TIMER(TCCR, A) = (1 << PWM_TIMER(WGM, 0)) | (1 << PWM_TIMER(COM, B1)) | (0 << PWM_TIMER(COM, B0));
    ldi r24, (1 << PWM_TIMER_S(WGM, 0)) | (1 << PWM_TIMER_S(COM, B1)) | (0 << PWM_TIMER_S(COM, B0))
    sts _SFR_MEM_ADDR(PWM_TIMER_S(TCCR, A)), r24

    // PWM_TIMER(TCCR, B) = (1 << PWM_TIMER(WGM, 3)) | (1 << PWM_TIMER(CS, 0));
    ldi r24, (1 << PWM_TIMER_S(WGM, 3)) | (1 << PWM_TIMER_S(CS, 0))
    sts _SFR_MEM_ADDR(PWM_TIMER_S(TCCR, B)), r24

    // PWM_TIMER(OCR, A) = PWM_HALF_PERIOD; // TOP
    ldi r24, lo8(PWM_HALF_PERIOD)
    ldi r25, hi8(PWM_HALF_PERIOD)
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, AH)), r25
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, AL)), r24

    // PWM_TIMER(OCR, B) = 0; // Duty Cycle
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH)), r1
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL)), r1

    // PWM_OUTPUT(DDR) = 1 << PWM_OUTPUT_BIT;
    ldi r24, 1 << PWM_OUTPUT_BIT
    out _SFR_IO_ADDR(PWM_OUTPUT(DDR)), r24

    // Setup rps detector timer to increment every 1024 cycles
    // RPS_DETECTOR_TIMER(TCCR, B) = (1 << RPS_DETECTOR_TIMER(CS, 2)) | (1 << RPS_DETECTOR_TIMER(CS, 0));
    ldi r24, (1 << RPS_DETECTOR_TIMER_S(CS, 2)) | (1 << RPS_DETECTOR_TIMER_S(CS, 0))
    sts _SFR_MEM_ADDR(RPS_DETECTOR_TIMER_S(TCCR, B)), r24

    // onInterrupt(RPS_DETECTOR_INT(INT, _vect_num), (void (*)(uint8_t))onDetectorFallingEdge);
    ldi r22, lo8(gs(onDetectorFallingEdge))
    ldi r23, hi8(gs(onDetectorFallingEdge))
    ldi r24, RPS_DETECTOR_INT_S(INT, _vect_num)
    call onInterrupt

    // setInterval((void (*)(uint8_t, bool))checkRps, 0, CHECK_RPS_INTERVAL, 0);
    clr r18
    clr r19
    ldi r20, lo8(CHECK_RPS_INTERVAL)
    ldi r21, hi8(CHECK_RPS_INTERVAL)
    clr r22
    ldi r24, lo8(gs(checkRps))
    ldi r25, hi8(gs(checkRps))
    jmp setInterval

// }
