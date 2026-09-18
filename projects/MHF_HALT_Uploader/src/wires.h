/* vim: ft=cpp showbreak=--»\  noexpandtab fileencoding=utf-8 nomodified wrap textwidth=0 foldmethod=marker foldmarker={{{,}}} foldcolumn=4 ruler showcmd lcs=tab\:|- list: tabstop=8 linebreak tags=./tags;,tags; 
 * */
// ,,g = gcc, exactly one space after "set"
//

#include <stdbool.h>

#define WIRE_UP(name,port,pin) bool name##_UP();
#define WIRE_DOWN(name,port,pin) bool name##_DOWN();
#define WIRE_IN(name,port,pin) bool name##_IN();
#define WIRE_HiZ(name,port,pin) bool name##_HiZ();
#define WIRE_PEEK(name,port,pin) bool name##_PEEK();
#define WIRE(name,port,pin) WIRE_UP(name,port,pin) \
	WIRE_DOWN(name,port,pin) \
	WIRE_IN(name,port,pin) \
	WIRE_HiZ(name,port,pin) \
	WIRE_PEEK(name,port,pin) 

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

uint8_t DATA_IN();
void DATA_HiZ();
void DATA_OUT(uint8_t val);
// uint16_t ADDR_IN();
void ADDR_HiZ();
void ADDR_OUT(uint16_t val);
void smallDelay();
void NOP(); // does nothing
