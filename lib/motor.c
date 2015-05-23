#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/io.h>

#include "circular-buffer.h"
#include "divmod.h"
#include "events.h"

#define HOLES_PER_REVOLUTION 4
#define MAX_RPS 100
#define RPS_SAMPLE_SIZE 4

#define CHECK_RPS_INTERVAL 150

#define PWM_HALF_PERIOD 1000 // In clock cycles (= TOP)
#define MIN_DUTY_CYCLE_STEP_INTERVAL 10
#define MAX_DUTY_CYCLE_STEP_INTERVAL 100

#define RPS_DETECTOR(reg) reg##D
#define RPS_DETECTOR_BIT PD2
#define RPS_DETECTOR_INT(reg, ...) reg##2##__VA_ARGS__
#define RPS_DETECTOR_TIMER(reg, ...) reg##4##__VA_ARGS__
#define RPS_DETECTOR_TICKS_PER_SECOND (F_CPU / 1024)

#define PWM_OUTPUT(reg) reg##E
#define PWM_OUTPUT_BIT PE4
#define PWM_TIMER(reg, ...) reg##3##__VA_ARGS__

static CircularBuffer rpsBuffer;
static uint8_t rpsRawBuffer[RPS_SAMPLE_SIZE];

static uint8_t targetRps;
static uint16_t topDutyCycle;
static uint16_t bottomDutyCycle;

uint8_t motorGetRps() {
    uint16_t rpsSum = 0;
    for (uint8_t i = 0; i < RPS_SAMPLE_SIZE; ++i)
        rpsSum += rpsRawBuffer[i];
    return rpsSum / RPS_SAMPLE_SIZE;
}

static void onDetectorFallingEdge() {
    static uint16_t lastTick;

    uint16_t now = RPS_DETECTOR_TIMER(TCNT);
    uint16_t delta_t = now - lastTick;
    lastTick = now;

    // Given a known max rps, there is a minimum delta_t
    // If the delta_t we get is lower than that minimum, discard the result
    if (delta_t < RPS_DETECTOR_TICKS_PER_SECOND / (HOLES_PER_REVOLUTION * MAX_RPS))
        return;

    uint8_t rps = udivmod16(RPS_DETECTOR_TICKS_PER_SECOND, delta_t * HOLES_PER_REVOLUTION);
    CircularBuffer_pushBack(&rpsBuffer, rps);
}

static void checkRps() {
    static uint16_t stepInterval;

    if (stepInterval == 0)
        stepInterval = MIN_DUTY_CYCLE_STEP_INTERVAL;

    uint8_t rps = motorGetRps();
    if (rps == targetRps)
        return;

    // Starts searching for the correct duty cycle's bounds by doubling the
    // search interval each step, then binary searches within those bounds.
    // This is done so the change in motor speed isn't too abrupt.

    uint16_t currentDutyCycle = PWM_TIMER(OCR, B);

    if (rps < targetRps) {
        if (topDutyCycle == currentDutyCycle) {
            bottomDutyCycle = currentDutyCycle;
            topDutyCycle += stepInterval;
            stepInterval *= 2;

            if (topDutyCycle > PWM_HALF_PERIOD)
                topDutyCycle = PWM_HALF_PERIOD;

            if (stepInterval > MAX_DUTY_CYCLE_STEP_INTERVAL)
                stepInterval = MAX_DUTY_CYCLE_STEP_INTERVAL;

            currentDutyCycle = topDutyCycle;
        } else {
            bottomDutyCycle = currentDutyCycle + 1;
            currentDutyCycle = (bottomDutyCycle + topDutyCycle) / 2;
            stepInterval = 0;
        }
    } else {
        if (bottomDutyCycle == currentDutyCycle) {
            bottomDutyCycle -= stepInterval;
            topDutyCycle = currentDutyCycle;
            stepInterval *= 2;

            if (bottomDutyCycle > PWM_HALF_PERIOD)
                // Underflowed
                bottomDutyCycle = 0;

            if (stepInterval > MAX_DUTY_CYCLE_STEP_INTERVAL)
                stepInterval = MAX_DUTY_CYCLE_STEP_INTERVAL;

            currentDutyCycle = bottomDutyCycle;
        } else {
            topDutyCycle = currentDutyCycle;
            currentDutyCycle = (bottomDutyCycle + topDutyCycle) / 2;
            stepInterval = 0;
        }
    }

    PWM_TIMER(OCR, B) = currentDutyCycle;
}

void motorSetRps(uint8_t rps) {
    targetRps = rps;
    topDutyCycle = bottomDutyCycle = PWM_TIMER(OCR, B);
}

void motorSetup() {
    CircularBuffer_init(&rpsBuffer, rpsRawBuffer, RPS_SAMPLE_SIZE, true);

    RPS_DETECTOR(DDR) &= ~(1 << RPS_DETECTOR_BIT);
    RPS_DETECTOR(PORT) |= 1 << RPS_DETECTOR_BIT;

    // Falling edge
    EICRA |= 1 << RPS_DETECTOR_INT(ISC, 1);
    EICRA &= ~(0 << RPS_DETECTOR_INT(ISC, 0));
    EIMSK |= 1 << RPS_DETECTOR_INT(INT);

    // Setup PWM timer in phase/frequency correct mode, with no prescaler
    // Clear/Set output on OCRnB compare match when up/down-counting
    PWM_TIMER(TCCR, A) = (1 << PWM_TIMER(WGM, 0)) | (1 << PWM_TIMER(COM, B1)) | (0 << PWM_TIMER(COM, B0));
    PWM_TIMER(TCCR, B) = (1 << PWM_TIMER(WGM, 3)) | (1 << PWM_TIMER(CS, 0));
    PWM_TIMER(OCR, A) = PWM_HALF_PERIOD; // TOP
    PWM_TIMER(OCR, B) = 0; // Duty Cycle
    PWM_OUTPUT(DDR) = 1 << PWM_OUTPUT_BIT;

    // Setup rps detector timer to increment every 1024 cycles
    RPS_DETECTOR_TIMER(TCCR, B) = (1 << RPS_DETECTOR_TIMER(CS, 2)) | (1 << RPS_DETECTOR_TIMER(CS, 0));

    onInterrupt(RPS_DETECTOR_INT(INT, _vect_num), (void (*)(uint8_t))onDetectorFallingEdge);
    setInterval((void (*)(uint8_t, bool))checkRps, 0, CHECK_RPS_INTERVAL, 0);
}
