; .. vim: ft=asm showbreak=--»\  noexpandtab fileencoding=utf-8 nomodified   wrap textwidth=0 foldmethod=marker foldmarker={{{,}}} foldcolumn=4 ruler showcmd lcs=tab\:|- list tabstop=8 noexpandtab nosmarttab softtabstop=0 shiftwidth=0 linebreak  tags=./tags;,tags; 
#include <avr/io.h>


#define WIRE_UP(name,port,pin) .global name##_UP $ name##_UP: $ sbi _SFR_IO_ADDR(PORT##port),pin $ sbi _SFR_IO_ADDR(DDR##port),pin $ ret $ 
#define WIRE_DOWN(name,port,pin) .global name##_DOWN $ name##_DOWN: $ cbi _SFR_IO_ADDR(PORT##port),pin $ sbi _SFR_IO_ADDR(DDR##port),pin $ ret $ 
#define WIRE_IN(name,port,pin) .global name##_IN $ name##_IN: $ cbi _SFR_IO_ADDR(PORT##port),pin $ cbi _SFR_IO_ADDR(DDR##port),pin $ clr r24 $ sbic _SFR_IO_ADDR(PIN##port),pin $ inc r24 $ ret $ 
#define WIRE_HiZ(name,port,pin) .global name##_HiZ $ name##_HiZ: $ cbi _SFR_IO_ADDR(PORT##port),pin $ cbi _SFR_IO_ADDR(DDR##port),pin $ ret $ 
#define WIRE_PEEK(name,port,pin) .global name##_PEEK $ name##_PEEK: $ clr r24 $ sbic _SFR_IO_ADDR(PIN##port),pin $ inc r24 $ ret $ 
#define WIRE(name,port,pin) WIRE_UP(name,port,pin) \
	WIRE_DOWN(name,port,pin) \
	WIRE_IN(name,port,pin) \
	WIRE_HiZ(name,port,pin) \
	WIRE_PEEK(name,port,pin) 

; WIRE_UP set pin to OUTPUT and it value to HIGH
; WIRE_DOWN set pin to OUTPUT and it value to LOW
; WIRE_IN set pin to INPUT and read it value
; WIRE_PEEK not set pin to anything, just read it value (can be used on both INPUT and OUTPUT pins)

.section .text.wires

WIRE(X_16,E,3)
WIRE(X_HALT,E,4)
WIRE(X_READ,D,7)
WIRE(X_SHARE_COOP,D,6)
WIRE(X_SHARE_GRANTED,D,4)
WIRE(X_SHARE_REQUEST,G,4)
// WIRE(X_S_SELECT,,)
// WIRE(X_S_READ,,)
// WIRE(X_S_WRITE,,)
WIRE(X_SHARE_SELECT,G,5)

; uint8_t DATA_HiZ();
.global DATA_HiZ
DATA_HiZ:
	clr r22
	sts DDRL,r22
	sts PORTL,r22
	ret

; uint8_t DATA_IN();
.global DATA_IN
DATA_IN:
	clr r22
	sts DDRL,r22
	sts PORTL,r22
	lds r24, PINL
	ret

;void DATA_OUT(uint8_t val);
.global DATA_OUT
DATA_OUT:
	ldi r22, 0xFF
	sts PORTL, r24
	sts DDRL,r22
	ret

;uint16_t ADDR_HiZ();
.global ADDR_HiZ
ADDR_HiZ:
	clr r22
	sts DDRJ,r22
	sts DDRK,r22
	sts PORTJ,r22
	sts PORTK,r22
	ret

;	;uint16_t ADDR_IN();
;	.global ADDR_IN
;	ADDR_IN:
;		clr r22
;		sts DDRJ,r22
;		sts DDRK,r22
;		sts PORTJ,r22
;		sts PORTK,r22
;		lds r24, PINJ
;		lds r25, PINK
;		ret

;void ADDR_OUT(uint16_t val);
.global ADDR_OUT
ADDR_OUT:
	ldi r22, 0xFF
	sts PORTJ, r24
	sts PORTK, r25
	sts DDRJ,r22
	sts DDRK,r22
	ret
	
; ================================================================================
; void smallDelay(); // 256 loops in asm {{{
.global smallDelay
smallDelay:
	clr	r24
;	clr	r23
	ldi	r23, 0x40
.L_smallDelay_loop:
	dec	r24
	brne	.L_smallDelay_loop
	dec	r23
	brne	.L_smallDelay_loop
	ret
; }}}

; void NOP(); // does nothing {{{
.global NOP
NOP:
	nop
	ret
; }}}
