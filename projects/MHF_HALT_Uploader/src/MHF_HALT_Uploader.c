/* vim: ft=cpp showbreak=--»\  noexpandtab fileencoding=utf-8 nomodified wrap textwidth=0 foldmethod=marker foldmarker={{{,}}} foldcolumn=4 ruler showcmd lcs=tab\:|- list: tabstop=8 linebreak  tags=./tags;,tags;
 * */
// ,,g = gcc, exactly one space after "set"
//
#include "MHF_HALT_Uploader.h"
#include "version.h"

#define TEXT __attribute__((section(".text.C_main")))
#define BSS(x) __attribute__((section(".bss" x)))
#define HIGHRAM(x) __attribute__((section(".highram" x)))
TEXT void write_char(char c){	// {{{
	TX0_Write(c);
}	// }}}
TEXT void write_charA(char c){	// {{{
	TX0_WriteA(c); 
}	// }}}
TEXT char read_char(){	// {{{
	return RX0_Read();
}	// }}}
TEXT void write_num8(uint8_t n) {	// {{{
	if (n>99) {
		write_char('0'+ n/100);
		n=n % 100;
		};
	if (n>9) {
		write_char('0'+ n/10);
		n=n % 10;
		};
		write_char('0'+n);
}	// }}}
TEXT uint32_t c_to_number(char *buf, uint8_t base) {	// {{{
    char *end;
    int neg = 0;
    int32_t val;

    if (*buf == 0)
        return 0;   // empty token = error

    /* <cnum>  := '<char>' */
    if (buf[0] == '\'' && buf[2] == '\'' && buf[3] == 0) {
        uint32_t r = (uint8_t)buf[1];
        return r | 0xFF000000;
    }

    /* radix prefixes */
    switch (*buf) {
        case '#': base = 10; buf++; break;
        case '$': base = 16; buf++; break;
        case '%': base = 2;  buf++; break;
        default: /* BASEnum */ break;
    }

    /* optional sign */
    if (*buf == '-') {
        neg = 1;
        buf++;
    }

    if (*buf == 0)
        return 0;   // "-" alone is invalid

    val = strtol(buf, &end, base);

    /* must consume whole token */
    if (*end != 0)
        return 0;

    if (neg)
        val = -val;

    /* truncate to CELL = 24 bit, add FF as 4.byte as sign of success */

    return val | 0xFF000000;
}	// }}}

HIGHRAM(".C_main") char str_buf[80];
TEXT uint32_t C_num2str(uint32_t num) {
	ltoa(num,str_buf,16);
	uint32_t adr=(uint16_t)str_buf;
	uint32_t len=strlen(str_buf);
	return adr+ (len <<16);
	
}
// ========================vvvv setup vvvv========================================= {{{
TEXT void setup(void) {
	usart0_setup();
	DebugLEDs_init();
}
// ========================^^^^ setup ^^^^========================================= }}}

TEXT void loop(void) {	// {{{
	uint16_t ch = RX0_Read();
	if (ch >> 8) { // Pokud r25 != 0
		TX0_Write((char)(ch & 0xFF)); // Blokuje dokud není volno
		if ((ch & 0xFF)==10)
			TX0_Write(13); // Blokuje dokud není volno
		if ((ch & 0xFF)==13)
			TX0_Write(10); // Blokuje dokud není volno
	};
}	// }}}
// ========================vvvv main vvvv========================================== {{{
TEXT int main(void) {
	setup();
	while (1) {
		loop();
	}
}
// ========================^^^^ main ^^^^========================================== }}}

