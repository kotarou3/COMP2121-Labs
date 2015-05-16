#ifndef UTIL_H
#define UTIL_H

#include <m2560def.inc>

#define INT0_vect_num 1
#define INT1_vect_num 2
#define INT2_vect_num 3
#define INT3_vect_num 4
#define INT4_vect_num 5
#define INT5_vect_num 6
#define INT6_vect_num 7
#define INT7_vect_num 8
#define PCINT0_vect_num 9
#define PCINT1_vect_num 10
#define PCINT2_vect_num 11
#define WDT_vect_num 12
#define TIMER2_COMPA_vect_num 13
#define TIMER2_COMPB_vect_num 14
#define TIMER2_OVF_vect_num 15
#define TIMER1_CAPT_vect_num 16
#define TIMER1_COMPA_vect_num 17
#define TIMER1_COMPB_vect_num 18
#define TIMER1_COMPC_vect_num 19
#define TIMER1_OVF_vect_num 20
#define TIMER0_COMPA_vect_num 21
#define TIMER0_COMPB_vect_num 22
#define TIMER0_OVF_vect_num 23
#define SPI_STC_vect_num 24
#define USART0_RX_vect_num 25
#define USART0_UDRE_vect_num 26
#define USART0_TX_vect_num 27
#define ANALOG_COMP_vect_num 28
#define ADC_vect_num 29
#define EE_READY_vect_num 30
#define TIMER3_CAPT_vect_num 31
#define TIMER3_COMPA_vect_num 32
#define TIMER3_COMPB_vect_num 33
#define TIMER3_COMPC_vect_num 34
#define TIMER3_OVF_vect_num 35
#define USART1_RX_vect_num 36
#define USART1_UDRE_vect_num 37
#define USART1_TX_vect_num 38
#define TWI_vect_num 39
#define SPM_READY_vect_num 40
#define TIMER4_CAPT_vect_num 41
#define TIMER4_COMPA_vect_num 42
#define TIMER4_COMPB_vect_num 43
#define TIMER4_COMPC_vect_num 44
#define TIMER4_OVF_vect_num 45
#define TIMER5_CAPT_vect_num 46
#define TIMER5_COMPA_vect_num 47
#define TIMER5_COMPB_vect_num 48
#define TIMER5_COMPC_vect_num 49
#define TIMER5_OVF_vect_num 50
#define USART2_RX_vect_num 51
#define USART2_UDRE_vect_num 52
#define USART2_TX_vect_num 53
#define USART3_RX_vect_num 54
#define USART3_UDRE_vect_num 55
#define USART3_TX_vect_num 56
#define _VECTORS_SIZE ((USART3_TX_vect_num << 2) + 4) // Size of all handlers in bytes

.macro hlt
    cli
    ldi r24, (1 << SM1) | (1 << SE) // SLEEP_MODE_PWR_DOWN
    out SMCR, r24
    sleep
.endm

.macro brz // target
    breq @0
.endm
.macro brnz // target
    brne @0
.endm

.macro skipIf // condition
    br@0 PC + 2
.endm
.macro skip2If // condition
    br@0 PC + 3
.endm

.macro lsln // reg, n
    rjmp b
a:
    lsl @0
b:
    dec @1
    brpl a
.endm
.macro lsrn // reg, n
    rjmp b
a:
    lsr @0
b:
    dec @1
    brpl a
.endm

#endif
