#include <avr/io.h>
#include <avr/interrupt.h>

;    PCMSK0 |= (1 << PCINT4); // Enable interrupt for PCINT4     
;    PCICR |= _BV(PCIE0);     // Enable Pin Change Interrupt for PCINT0

#define DEBUG
#ifdef DEBUG
; === DEBUG {{{

.global RX0_Count
.global RX0_Head
.global RX0_Tail
.global RX0_Buffer

.global TX0_Count
.global TX0_Head
.global TX0_Tail
.global TX0_Buffer
.global Hex_Buffer
#endif
; }}}

; === Konstanta pro baud rate 115200 při 16 MHz a U2Xn = 0: UBRR = 8
.equ BAUD_UBRR,8

; === RTS / CTS PINY B5/B4
.equ RTS_PIN,5
#define RTS_PORT(name) name##B
.equ CTS_PIN,4
#define CTS_PORT(name) name##B


.macro IRQ_push_entry	; {{{
	push r1
	push r0
	in r0,_SFR_IO_ADDR(SREG)
	push r0
	in r0,_SFR_IO_ADDR(RAMPZ)
	push r0
	clr r1	; use for 0
.endm			; }}}
.macro IRQ_push_16_20_Z	; {{{
	push r16
	push r17
	push r18
	push r19
	push r20
	push ZL
	push ZH
.endm			; }}}
.macro IRQ_pop_16_20_Z	; {{{
	pop ZH
	pop ZL
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
.endm			; }}}
.macro IRQ_pop_entry	; {{{
	pop r0
	out _SFR_IO_ADDR(RAMPZ),r0
	pop r0
	out _SFR_IO_ADDR(SREG),r0
	pop r0
	pop r1
.endm			; }}}

; === RX/TX buffer velikosti
.equ RX0_BUFFER_SIZE,120
.equ RX0_BUFFER_THRESHOLD,16
.equ TX0_BUFFER_SIZE,120

; === data {{{
.section .bss.LIBS
ignoreme_1: .byte 0
RX0_Count:		.byte 0	; if zero, head==tail means empty, if RX0_BUFFER_SIZE,  head==tail means full
RX0_Head:		.byte 0	; new character will came here
RX0_Tail:		.byte 0	; outcoming character will came from here
RX0_Buffer:		.zero RX0_BUFFER_SIZE	; data

TX0_Count:		.byte 0
TX0_Head:		.byte 0
TX0_Tail:		.byte 0
TX0_Buffer:		.skip TX0_BUFFER_SIZE
Hex_Buffer:		.skip 9	; 32bit string + \0

.type RX0_Count, @object
.type RX0_Head, @object
.type RX0_Tail, @object
.type RX0_Buffer, @object

.type TX0_Count, @object
.type TX0_Head, @object
.type TX0_Tail, @object
.type TX0_Buffer, @object
.type Hex_Buffer, @object

ignoreme_2: .byte 0
; === }}}
.section .text.LIBS.main

; nop	; ctors end and trampolines will be here, lets have RESET named

; === setup()
.global usart0_setup
usart0_setup:		; destroy r24 {{{
	sts RX0_Count, r1
	sts RX0_Head,  r1
	sts RX0_Tail,  r1
	sts TX0_Count, r1
	sts TX0_Head,  r1
	sts TX0_Tail,  r1
;
	; USART0 init: 8N1, RX+TX enable, RX interrupt, UDRE interrupt enable (TX)
	ldi r24, hi8(BAUD_UBRR)
	sts UBRR0H, r24
	ldi r24, lo8(BAUD_UBRR)
	sts UBRR0L, r24

;	ldi r24, 0	; U2Xn = 0
	ldi r24, (0 << RXC0) | (0 << TXC0) | (0 << UDRE0) | (0 << FE0) | (0 << DOR0) | (0 << UPE0) | (0 << U2X0) | (0 << MPCM0) 
	sts UCSR0A, r24		; pg 219; Status registr
		;	Bit 1 – U2Xn: Double the USART Transmission Speed
		;	This bit only has effect for the asynchronous operation. Write this bit to zero when using synchronous operation.
		;	Writing this bit to one will reduce the divisor of the baud rate divider from 16 to 8 effectively doubling the transfer rate for asynchronous communication.
		;	• Bit 0 – MPCMn: Multi-processor Communication Mode
		;	This bit enables the Multi-processor Communication mode. When the MPCMn bit is written to one, all the incoming frames received by the USART Receiver that do not contain address information will be ignored. The Transmitter is unaffected by the MPCMn setting.


	ldi r24, (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0) | (0 << TXCIE0) | (1 << UDRIE0)
	sts UCSR0B, r24 ; pg 220, Enable registr
		; enable Receiver, Transmitter,  RX Complete, USART Data Register Empty , TX Complete (with reti only)
		;	UCSRnB
		;	• Bit 7 – RXCIEn: RX Complete Interrupt Enable n
		;	Writing this bit to one enables interrupt on the RXCn Flag. A USART Receive Complete interrupt will be generated only if the RXCIEn bit is written to one, the Global Interrupt Flag in _SFR_IO_ADDR(SREG) is written to one and the RXCn bit in UCSRnA is set.
		;	• Bit 6 – TXCIEn: TX Complete Interrupt Enable n
		;	Writing this bit to one enables interrupt on the TXCn Flag. A USART Transmit Complete interrupt will be generated only if the TXCIEn bit is written to one, the Global Interrupt Flag in _SFR_IO_ADDR(SREG) is written to one and the TXCn bit in UCSRnA is set.
		;	• Bit 5 – UDRIEn: USART Data Register Empty Interrupt Enable n
		;	Writing this bit to one enables interrupt on the UDREn Flag. A Data Register Empty interrupt will be generated only if the UDRIEn bit is written to one, the Global Interrupt Flag in _SFR_IO_ADDR(SREG) is written to one and the UDREn bit in UCSRnA is set.
		;  we need UDRIEn, but not TXCIEn
		;	• Bit 4 – RXENn: Receiver Enable n
		;	Writing this bit to one enables the USART Receiver. The Receiver will override normal port operation for the RxDn pin when enabled. Disabling the Receiver will flush the receive buffer invalidating the FEn, DORn, and UPEn Flags.
		;	• Bit 3 – TXENn: Transmitter Enable n
		;	Writing this bit to one enables the USART Transmitter. The Transmitter will override normal port operation for the TxDn pin when enabled. The disabling of the Transmitter (writing TXENn to zero) will not become effective until ongoing and pending transmissions are completed, that is, when the Transmit Shift Register and Transmit Buffer Register do not contain data to be transmitted. When disabled, the Transmitter will no longer override the TxDn port.
		;	• Bit 2 – UCSZn2: Character Size n
		;	The UCSZn2 bits combined with the UCSZn1:0 bit in UCSRnC sets the number of data bits (Character SiZe) in a frame the Receiver and Transmitter use.
		;	• Bit 1 – RXB8n: Receive Data Bit 8 n
		;	RXB8n is the ninth data bit of the received character when operating with serial frames with nine data bits. Must be read before reading the low bits from UDRn.
		;	• Bit 0 – TXB8n: Transmit Data Bit 8 n
		;	TXB8n is the ninth data bit in the character to be transmitted when operating with serial frames with nine data bits.  Must be written before writing the low bits to UDRn.


	ldi r24, (1 << UCSZ01) | (1 << UCSZ00)
	sts UCSR0C, r24
		; Asynchronous USART, Parity Mode disabled, Stop Bit(s) 1, Character Size = 8bit, Clock Polarity =0

	; RTS pin jako výstup
	sbi _SFR_IO_ADDR(RTS_PORT(DDR)), RTS_PIN
	cbi _SFR_IO_ADDR(RTS_PORT(PORT)), RTS_PIN	   ; výchozí: RTS = 0 (můžeme přijímat)

	; CTS pin jako vstup
	; Nastavení PB4 jako vstupu (pokud už není)
	cbi _SFR_IO_ADDR(CTS_PORT(DDR)), CTS_PIN
	sbi _SFR_IO_ADDR(CTS_PORT(PORT)), CTS_PIN	   ; pull-up

	; CTS pin jako zdroj interruptu
;	lds r24, EICRA		; EICRA pg.110
;	andi r24, 0b00111111
;	ori r24,  0b00100000  ; ISC21:20 = 10 → falling edge
;	sts EICRA, r24		; OVERIT PIN

;	sbi _SFR_IO_ADDR(EIMSK), INT3      ; povolit INT3
;	sbis _SFR_IO_ADDR(CTS_PORT(PIN)), CTS_PIN	; CTS check – if is low, we can send so no need for INT
;	cbi _SFR_IO_ADDR(EIMSK), INT3      ; zakazat INT3


	; Povolení Pin Change Interruptu pro PB4
	; PCMSK0 registrem vybíráme, které piny z Portu B budou generovat interrupt
	lds r24, PCMSK0
	ori r24, (1 << PCINT4) ; Bit 4 odpovídá PB4
	sts PCMSK0, r24

	; Povolení celé skupiny PCINT0 (Port B) v globálním registru PCICR
	; lds r24, PCICR
	; ori r24, (1 << PCIE0)  ; Povolit PCINT0_vect (az kdyz bude potreba)
	; sts PCICR, r24
	ret
; === }}}

; === USART0 RX ISR {{{

.global __vector_25
__vector_25:
.global USART0_RX_ISR
USART0_RX_ISR:
	IRQ_push_entry
	IRQ_push_16_20_Z
	lds r16, UDR0	; incomming data

	; count ok?
	lds r18, RX0_Count
	cpi r18, RX0_BUFFER_SIZE-1	; is buffer full?
	breq .L_RX0_exit ; if yes, exit and ignore this char

	lds r19, RX0_Head	; not full, add char
	ldi ZL, lo8(RX0_Buffer)
	ldi ZH, hi8(RX0_Buffer)
	add ZL, r19
	adc ZH, r1
	st Z, r16
	inc r18		; RX0_Count++
	sts RX0_Count, r18
	inc r19		; HEAD++
	cpi r19, RX0_BUFFER_SIZE
	brlt 1f	; modulo overflow?
	clr r19			; yes, max->0
1:
	sts RX0_Head, r19	; normal way

	cpi r18, RX0_BUFFER_SIZE - RX0_BUFFER_THRESHOLD	; RTS: is nearly full?
	brlt RTS_CLEAR
	sbi _SFR_IO_ADDR(RTS_PORT(PORT)), RTS_PIN	; if yes set RTS 
	rjmp .L_RX0_exit
RTS_CLEAR:
;	cbi _SFR_IO_ADDR(RTS_PORT(PORT)), RTS_PIN	;if not, clear RTS - do not clear, until buffer empty and RX0_Read occure

.L_RX0_exit:
	IRQ_pop_16_20_Z
	IRQ_pop_entry
	reti
; === }}}
; === RX0_Read: Výstup r24 = znak, r25 = delka bufferu PRED ctenim (1..RX0_BUFFER_SIZE) pokud data, jinak 0; uses r18,r19,r20,Z {{{
.global RX0_Read
RX0_Read:
	lds r18, RX0_Count
	mov r25,r18
	cpi r18, 0
	breq .L_RX0_empty
	lds r19, RX0_Tail
	ldi ZL, lo8(RX0_Buffer)
	ldi ZH, hi8(RX0_Buffer)
	add ZL, r19
	adc ZH, r1
	ld r24, Z
	in r20,_SFR_IO_ADDR(SREG)
	cli			; ==== no interrupts here
	lds r18, RX0_Count	; RX0_Count --
	dec r18
	sts RX0_Count, r18
	out _SFR_IO_ADDR(SREG),r20		; ==== ok
	inc r19
	cpi r19, RX0_BUFFER_SIZE
	brlt 1f
	clr r19
1:
	sts RX0_Tail, r19
;	ldi r25, 1
	ret
.L_RX0_empty:
	cbi _SFR_IO_ADDR(RTS_PORT(PORT)), RTS_PIN	; clear RTS
	clr r24
;	clr r25
	ret
; === }}}
; === RX0_Available: r24 = RX0_Count (# of waiting chars) {{{
.global RX0_Available
RX0_Available:
	lds r24,RX0_Count
	ret
; === }}}
; === USART0 UDRE ISR	 - is output register empty? {{{

.global __vector_26
__vector_26:
.global USART0_UDRE_ISR
USART0_UDRE_ISR:
	IRQ_push_entry
	
	sbis _SFR_IO_ADDR(CTS_PORT(PIN)), CTS_PIN	; CTS check – if is low, we can send
;	NOP ; FIXME suppose we can send anytime
	rjmp TX_send		; yes, we can
				; no we cannot - disable USART0_UDRE_ISR, enable CTS_PIN INTR
	
	; Povolení celé skupiny PCINT0 (Port B) v globálním registru PCICR
	lds r24, PCICR
	ori r24, (1 << PCIE0)  ; Povolit PCINT0_vect (az kdyz bude potreba)
	sts PCICR, r24
; USART0_UDRE_ISR_disable:
	push r16
	lds r16, UCSR0B		; disable us
	andi r16, ~(1 << UDRIE0)
	sts UCSR0B, r16

	pop r16
	IRQ_pop_entry
	reti

TX_send:
	IRQ_push_16_20_Z

	lds r18, TX0_Count
	cpi r18, 0
	breq .L_TX0_empty

	lds r19, TX0_Tail
	ldi ZL, lo8(TX0_Buffer)
	ldi ZH, hi8(TX0_Buffer)
	add ZL, r19
	adc ZH, r1
	ld  r16,Z
	sts UDR0, r16	; send it
	dec r18		; TX0_Count--
	sts TX0_Count, r18
	inc r19		; Tail++
	cpi r19, TX0_BUFFER_SIZE
	brlt 1f	; modulo overflow?
	clr r19			; yes, max->0
1:
	sts TX0_Tail, r19	; normal way

	rjmp .L_TX0_exit
.L_TX0_empty:
	; zakázat UDRE interrupt pokud nic k odeslání
	lds r16, UCSR0B
	andi r16, ~(1 << UDRIE0)
	sts UCSR0B, r16
.L_TX0_exit:
	IRQ_pop_16_20_Z
	IRQ_pop_entry
	reti
; === }}}
; === PCINT0 Pin Changed PB0..PB7 {{{
.global __vector_9
__vector_9:

.global PCINT0_ISR
PCINT0_ISR:
	; called when CTS is low and send is still blocked (check this)
	IRQ_push_entry
	sbic _SFR_IO_ADDR(PINB), 4 ; Skip if Bit in I/O register is Clear (CTS is low)
	rjmp .L_PCINT0_exit        ; Pokud je 1 (Set), je stále zakázán, snad příště ...
	lds r24, PCICR
	andi r24, ~(1 << PCIE0)  
	sts PCICR, r24
	;
	push r16
	lds r16, UCSR0B		; enable TX
	ori r16, (1 << UDRIE0)
	sts UCSR0B, r16

	pop r16
.L_PCINT0_exit:
	IRQ_pop_entry
	reti


; === }}}
; === TX0_WriteA: vstup r24 = znak, blokuje při plném bufferu, vystup r24 - aktualni delka bufferu; uses r18, r19, r20, Z {{{ pise pouze ASCII
.global TX0_WriteA
TX0_WriteA:
	sbrc r24,7
	ldi r24, '.'
	cpi r24, ' '
	brsh TX0_Write
	ldi r24, '.'
; }}} fall thru
; === TX0_Write: vstup r24 = znak, blokuje při plném bufferu, vystup r24 - aktualni delka bufferu; uses r18, r19, r20, Z {{{
.global TX0_Write
TX0_Write:
	lds r18, TX0_Count
	cpi r18, TX0_BUFFER_SIZE-1
	breq TX0_Write
	lds r19, TX0_Head
	ldi ZL, lo8(TX0_Buffer)
	ldi ZH, hi8(TX0_Buffer)
	add ZL, r19
	adc ZH, r1
	st Z, r24
	in r20,_SFR_IO_ADDR(SREG)
	cli			; ==== no interrupts here
	lds r18, TX0_Count	; TX0_Count ++
	inc r18
	sts TX0_Count, r18
	out _SFR_IO_ADDR(SREG),r20		; ==== ok
	lds r19, TX0_Head
	inc r19
	cpi r19, TX0_BUFFER_SIZE
	brlt 1f
	clr r19
1:
	sts TX0_Head, r19

	; povolit UDRE interrupt
	lds r20, UCSR0B
	ori r20, (1 << UDRIE0)
	sts UCSR0B, r20
	mov r24,r18
	ret
; === }}}
; === TX0_Used: output: r24 used space in TX buffer {{{
.global TX0_Used
TX0_Used:
	lds r24, TX0_Count
	ret
; === }}}
; === TX0_Free: output: r24 available space in TX buffer {{{
.global TX0_Free
TX0_Free:
	ldi r24, TX0_BUFFER_SIZE
	lds r25, TX0_Count
	sub r24,r25
	ret
; === }}}
; === uint8_t TX0_WriteStr(char *c);	// Cstring, r24,r25 in, out r24=buf_used. BLOCKS if buffer full uses r24, r25, r22,r23 + TX0_Write (r18,r19,r20,Z) {{{ 
.global TX0_WriteStr
TX0_WriteStr:
	movw r22, r24
1:
	movw r30, r22
	ld r24,Z+
	movw r22,r30
	tst r24
	breq 2f
	rcall TX0_Write
	rjmp 1b
2:
	rcall TX0_Used
	ret
; === }}}
; === uint8_t TX0_WriteBin8(uint8_t h);	//  101010101010, r24=buf_used. BLOCKS if buffer full {{{
.global TX0_WriteBin8
TX0_WriteBin8:
	mov r23, r24
	ldi r21, 8
1:
	ldi r24, '0
	lsl r23
	adc r24, r1
	rcall TX0_Write
	dec r21
	brne 1b
	ret
; === }}}
; === uint8_t TX0_WriteHex8(uint8_t h);	//       0A, r24=buf_used. BLOCKS if buffer full {{{
.global TX0_WriteHex8
TX0_WriteHex8:
	mov r23, r24
	swap r24
	rcall Hex4
	rcall TX0_Write
	mov r24,r23
	rcall Hex4
	rcall TX0_Write
	ret
; === }}}
; === uint8_t TX0_WriteHex16(uint16_t h);	//     0A0D , r24=buf_used. BLOCKS if buffer full {{{
.global TX0_WriteHex16
TX0_WriteHex16:
	mov r21,r24
	mov r24, r25
	rcall TX0_WriteHex8
	mov r24,r21
	rjmp TX0_WriteHex8
; === }}}
; === uint8_t TX0_WriteHex24(uint32_t h);	//   0A0D0C , r24=buf_used. BLOCKS if buffer full {{{
.global TX0_WriteHex24
TX0_WriteHex24:
	mov r21,r23
	rcall TX0_WriteHex8
	mov r24, r21
	rcall TX0_WriteHex8
	mov r24,r22
	rjmp TX0_WriteHex8
; === }}}
; === uint8_t TX0_WriteHex32(uint32_t h);	// 0A0D0C0D , r24=buf_used. BLOCKS if buffer full {{{
.global TX0_WriteHex32
TX0_WriteHex32:
	push r22
	push r23
	rcall TX0_WriteHex16
	pop r25
	pop r24
	rjmp TX0_WriteHex16
; === }}}
; === char Hex4(uint8_t h);	// '0'..'F', h & 0x0F {{{
.global Hex4
Hex4:
	andi r24, 0xF
	cpi r24, 10
	brlo 1f
	subi r24, - ('A - '0 -10)
1:
	subi r24, - '0
ret
; === }}}
