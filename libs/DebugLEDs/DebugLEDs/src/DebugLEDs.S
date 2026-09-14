#include <avr/io.h>
#include <avr/interrupt.h>

#define DebugLEDs_PORT(name) name##D
#define DebugLEDs_PIN 4
#define DebugLEDs_count 6
.section .bss.bios
.global DebugLEDs_values
DebugLEDs_values:
	.space 3*6
.section .text.bios
.global DebugLEDs_init 
DebugLEDs_init:
	ldi r24, 3 * DebugLEDs_count
	ldi ZL, lo8(DebugLEDs_values)
	ldi ZH, hi8(DebugLEDs_values)
1:
	st  Z+,r1
	dec r24
	brne 1b
;	rjmp DebugLEDs_show
.global DebugLEDs_show
DebugLEDs_show:
	PUSH   r16
	PUSH   r17
	PUSH   r28
	PUSH   r29
	sbi _SFR_IO_ADDR(DebugLEDs_PORT(DDR )), DebugLEDs_PIN
	cbi _SFR_IO_ADDR(DebugLEDs_PORT(PORT)), DebugLEDs_PIN
	CLI
	ldi r28, DebugLEDs_count+1	; num of LEDs
	ldi r16, lo8(DebugLEDs_values)
	ldi r17, hi8(DebugLEDs_values)
DebugLEDS__while_count:
	dec   r28		; next LED
	BRNE   1f
	RJMP   DebugLeds__end_while
1:
	MOVW   r30, r16
	LD     r0, Z+
	LD     r0, Z
	RCALL  send_led_strip_byte
	LD     r0, -Z
	RCALL  send_led_strip_byte
	LD     r0, Z+
	LD     r0, Z+
	LD     r0, Z+
	RCALL  send_led_strip_byte
	RJMP   led_strip_asm_end

////////////////////////////////////////////////////////////////////////////////

send_led_strip_byte:
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RCALL  send_led_strip_bit
	RET

////////////////////////////////////////////////////////////////////////////////

send_led_strip_bit:
	SBI    _SFR_IO_ADDR(DebugLEDs_PORT(PORT)), DebugLEDs_PIN
	ADC    r0, r0
	NOP
	NOP
	BRCS   1f
	CBI    _SFR_IO_ADDR(DebugLEDs_PORT(PORT)), DebugLEDs_PIN
1:
	NOP
	NOP
	NOP
	NOP
	NOP
	BRCC  1f 
	CBI    _SFR_IO_ADDR(DebugLEDs_PORT(PORT)), DebugLEDs_PIN
1:
	RET
led_strip_asm_end:
	MOVW   r16, r30
	RJMP   DebugLEDS__while_count
DebugLeds__end_while:
	SEI
	LDI    r24, 0x3b
	LDI    r25, 0x01
Lbl_00449:
	SBIW   r24, 0x01
	BRNE   Lbl_00449
	POP    r29
	POP    r28
	POP    r17
	POP    r16
	RET

.global DebugLEDs_setRGB
DebugLEDs_setRGB:
	cpi r24, 6
	brsh DebugLEDs_setRGB_exit
	ldi ZL, lo8(DebugLEDs_values)
	ldi ZH, hi8(DebugLEDs_values)
	mov r25,r24
	add r25,r24
	add r25,r24
	add ZL,r25
	adc ZH,r1
	st  Z+,r22
	st  Z+,r20
	st  Z+,r18
DebugLEDs_setRGB_exit:
	ret


