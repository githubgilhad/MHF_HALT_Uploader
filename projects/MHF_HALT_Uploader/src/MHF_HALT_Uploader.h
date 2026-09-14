/* vim: ft=cpp showbreak=--»\  noexpandtab fileencoding=utf-8 nomodified wrap textwidth=0 foldmethod=marker foldmarker={{{,}}} foldcolumn=4 ruler showcmd lcs=tab\:|- list: tabstop=8 linebreak tags=./tags;,tags; 
 * */
// ,,g = gcc, exactly one space after "set"
//
#pragma once
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <string.h>

#include "usart0.h"
#include "DebugLEDs.h"


extern uint8_t __data_start;
extern uint8_t __data_end;
extern uint8_t __highram_start;
extern uint8_t __highram_end;
extern uint8_t __bss_start;
extern uint8_t __bss_end;
extern uint8_t __noinit_start;
extern uint8_t __noinit_end;
extern uint8_t __heap_start;
