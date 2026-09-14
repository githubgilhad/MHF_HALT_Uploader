#ifndef USART0_H
#define USART0_H
#pragma once

void usart0_setup();
uint16_t RX0_Read();		// r24 = character (or 0), r25 = 0 if no char available, buf_used+1 otherwise
uint8_t TX0_Write(char c);	// c=char to write, r24=buf_used. BLOCKS if buffer full
uint8_t TX0_WriteA(char c);	// c=char to write, r24=buf_used. BLOCKS if buffer full, writes only ASCII
uint8_t RX0_Available();	// available chars in RX buffer
uint8_t TX0_Used();		// used space in TX buffer
uint8_t TX0_Free();		// available space in TX buffer
//
uint8_t TX0_WriteStr(char *c);	// Cstring, r24=buf_used. BLOCKS if buffer full
uint8_t TX0_WriteBin8(uint8_t h);	//  101010101010, r24=buf_used. BLOCKS if buffer full
uint8_t TX0_WriteHex8(uint8_t h);	//       0A, r24=buf_used. BLOCKS if buffer full
uint8_t TX0_WriteHex16(uint16_t h);	//     0A0D , r24=buf_used. BLOCKS if buffer full
uint8_t TX0_WriteHex24(uint32_t h);	//   0A0D0C , r24=buf_used. BLOCKS if buffer full
uint8_t TX0_WriteHex32(uint32_t h);	// 0A0D0C0D , r24=buf_used. BLOCKS if buffer full
char Hex4(uint8_t h);	// '0'..'F', h & 0x0F
// not needed here, gcc automagically links __vector_xx on the right places (starting with __vector_00 for RESET)
void __vector_26();
void USART0_RX_ISR();
void __vector_27();
void USART0_UDRE_ISR();
void __vector_9();
void PCINT0_ISR();

#endif
