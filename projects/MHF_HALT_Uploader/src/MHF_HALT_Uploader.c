/* vim: ft=cpp showbreak=--»\  noexpandtab fileencoding=utf-8 nomodified wrap textwidth=0 foldmethod=marker foldmarker={{{,}}} foldcolumn=4 ruler showcmd lcs=tab\:|- list: tabstop=8 linebreak  tags=./tags;,tags;
 * */
// ,,g = gcc, exactly one space after "set"
//
#include "MHF_HALT_Uploader.h"
#include "version.h"
#include "wires.h"

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
TEXT uint32_t C_num2str(uint32_t num) {	// {{{
	ltoa(num,str_buf,16);
	uint32_t adr=(uint16_t)str_buf;
	uint32_t len=strlen(str_buf);
	return adr+ (len <<16);
	
}	// }}}}
TEXT uint16_t RX0_ReadHex4() {	// {{{ r24=value, r25==0 - OK, ==1 problem, BLOCKS
	uint16_t ch;
//	ch = RX0_Read();
	while (1) {
//		smallDelay();	// DELETEME : remove XXX
		ch = RX0_Read();
		if (!(ch >> 8)) continue; // Pokud r25 != 0
		ch = ch & 0xFF;
		if ((ch >='0') && (ch <='9')) return ch - '0';
		if ((ch >='a') && (ch <='f')) return ch - 'a' + 10;
		if ((ch >='A') && (ch <='F')) return ch - 'A' + 10;
		return 0x100;
	};
}	// }}}
TEXT uint16_t RX0_ReadHex8() {	// {{{ r24=value, r25==0 - OK, ==1 problem, BLOCKS
	uint16_t r1,r2;
	r1 = RX0_ReadHex4();
	if (r1 > 0xFF) return r1;
	r2 = RX0_ReadHex4();
	if (r2 > 0xFF) return r2;
	return (r1 << 4) | r2;
}	// }}}
TEXT uint8_t SkipLine(uint16_t x, char *p) {	// {{{ if x > 0xFF, print *p, skip line, return 1; else return 0
	uint16_t ch;
	if (x > 0xFF) {
		TX0_WriteStr(" ## ");
		TX0_WriteStr(p);
		TX0_WriteStr("\r\n");
		while (1) {
			ch = RX0_Read();
			if (!(ch >> 8)) continue; // Pokud r25 != 0
			if (((ch & 0xFF) == 10) || ((ch & 0xFF) ==  13)) break;
		};
		return 1;
	};
	return 0;
}	// }}}
uint16_t ext_addr;
TEXT void help() {	// {{{
	TX0_WriteStr("  --==## MHF_HALT_Uploader ##==--\r\n");
	TX0_WriteStr("ver. " VERSION_STRING " from " BUILD_DATE " " BUILD_TIME  "\r\n");
	TX0_WriteStr("git * " VERSION_COMMIT " - " VERSION_MESSAGE "\r\n");
	TX0_WriteStr("	h H ? - this help\r\n");
	TX0_WriteStr("	r R   - release from A_HALT (~Reset/Reboot)\r\n");
	TX0_WriteStr("	a A   - attach by A_HALT\r\n");
	TX0_WriteStr("	:     - rest of line is I32HEX for Comp24 RAM\r\n");
	TX0_WriteStr("	x X   - Xcopy = copy chars to output until next x/X\r\n");
	TX0_WriteStr("Extended Memory: ");TX0_WriteHex8(ext_addr); TX0_WriteStr("; ");
	TX0_WriteStr("SHARE GRANTED: ");
	if(X_SHARE_GRANTED_IN()) {
		TX0_WriteStr("Yes");
	} else {
		TX0_WriteStr("No"); 
	};
	TX0_WriteStr("; ");
	if (X_HALT_PEEK()) {
		TX0_WriteStr("HALT NOT active\r\n");
	} else {
		TX0_WriteStr("HALT Active\r\n");
	};
}	// }}}
TEXT void Attach() {	// {{{
	TX0_WriteStr("Attach starting\r\n");
	if (X_HALT_PEEK()) {
		TX0_WriteStr("### Attach: X_HALT is High!!! \r\n");
	};
	X_HALT_DOWN();	// preberem spravu X_HALT
	X_READ_UP();	// nechceme nahodne prepsat neco
	// -----
	X_SHARE_SELECT_DOWN();	// Spravujeme SystemRAM (nikoli SharedRAM)
	X_SHARE_REQUEST_UP();	// Chceme pristup (k vecem obecne)
	TX0_WriteStr("Attach waiting\r\n");
	if (false) // DELETEME
	while(! X_SHARE_GRANTED_IN()) {		// dokud nedostaneme pristup cekame
		smallDelay();
	};			// nyni mam X_SHARE_GRANTED a tudíž
				// vzhledem k X_SHARE_SELECT == 0 gates jsou OPEN, address smerem MHF->CPU, data dle X_READ (1=CPU->MHF)
				// X_SHARE_COOP zde nepouzivame
	ext_addr=0;

	TX0_WriteStr("Attached\r\n");
}	// }}}
TEXT void Release() {	// {{{
	X_SHARE_REQUEST_DOWN();	// vzdame se pristupu
	X_HALT_UP();		// a odlogujeme se z HALTu
	ext_addr=0;
	TX0_WriteStr("Released\r\n");
}	// }}}
TEXT void IHEX() {	// {{{
	uint16_t len,type, crc, ch, crc_data;
	uint32_t addr;
	TX0_WriteStr(":");
	if (SkipLine(X_HALT_PEEK()?0x100:0, "Not in HALT mode!!!")) return;	// HALT je active LOW
	
	// ono to uz asi mame nastavene spravne, ale ted si to overime pred zapisem:
	X_READ_UP();	// nechceme nahodne prepsat neco
	// -----
	X_SHARE_SELECT_DOWN();	// Spravujeme SystemRAM (nikoli SharedRAM)
	X_SHARE_REQUEST_UP();	// Chceme pristup (k vecem obecne)
	if (false) // DELETEME
	while(! X_SHARE_GRANTED_IN()) {		// dokud nedostaneme pristup cekame
		smallDelay();
	};			// nyni mam X_SHARE_GRANTED a tudíž
				// vzhledem k X_SHARE_SELECT == 0 gates jsou OPEN, address smerem MHF->CPU, data dle X_READ (1=CPU->MHF)
				// X_SHARE_COOP zde nepouzivame
	// OK, jsme pripraveni zapisovat, pokud to bude potreba
	len = RX0_ReadHex8();
	if (SkipLine(len,"Bad len")) return;
	TX0_WriteHex8(len);
	TX0_Write(' ');
	crc_data=len;
	
	addr = RX0_ReadHex8();
	if (SkipLine(addr,"Bad addr1")) return;
	TX0_WriteHex8(addr);
	crc_data=(crc_data+addr) & 0xFF;
	
	ch = RX0_ReadHex8();
	if (SkipLine(ch,"Bad addr2")) return;
	TX0_WriteHex8(ch);
	crc_data=(crc_data+ch) & 0xFF;
	addr = addr << 8 | ch;
	TX0_Write(' ');
	
	type = RX0_ReadHex8();
	if (SkipLine(type,"Bad type")) return;
	TX0_WriteHex8(type);
	crc_data=(crc_data+type) & 0xFF;
	TX0_Write(' ');
	
	// data type:
	switch(type) {
		case 00: // Data
			break;
		case 01: // End of File
			SkipLine(0x100,"End of File - OK");
			return;
			break;
		case 02: // Extended Segment Address
			SkipLine(0x100,"02 Extended Segment Address - unsupported");
			return;
			break;
		case 03: // Start Segment Address
			SkipLine(0x100,"03 Start Segment Address - unsupported");
			return;
			break;
		case 04: // Data
			ch = RX0_ReadHex8();
			TX0_WriteHex8(ch);
			if (SkipLine((ch==0)?0:0x100,"04 Extended Linear Address - must be 0/1 - Bad data[0]")) return;
			ch = RX0_ReadHex8();
			TX0_WriteHex8(ch);
			if (SkipLine((ch<2)?0:0x100,"04 Extended Linear Address - must be 0/1 - Bad data[1]")) return;
			ext_addr = ch;
			SkipLine(0x100,"04 Extended Linear Address - OK");
			return;
			break;
		case 05: // Start Linear Address
			SkipLine(0x100,"05 Start Linear Address - unsupported");
			return;
			break;
		default: // other
			SkipLine(0x100,"unknonw number - unsupported");
			return;
			break;
	};
	// jedina sance se dostat sem jsou 00 - Data
	
	for (uint16_t i=0; i<len;i++) {
		ch = RX0_ReadHex8();
		if (SkipLine(ch,"Bad data")) return;
		TX0_WriteHex8(ch);
		crc_data=(crc_data+ch) & 0xFF;
		if (ext_addr) {
			X_16_UP();
		} else {
			X_16_DOWN();
		};
		// write ch to (ext_addr,addr) in RAM
		X_READ_UP();	// safely set addr
		ADDR_OUT(addr);
		X_READ_DOWN();	// write anything
		DATA_OUT(ch);	// write real data
		NOP();
		X_READ_UP();	// read back, safe conflict on bus
		DATA_HiZ();
		ADDR_HiZ();
		addr++;
	};
	TX0_Write(' ');
	crc = RX0_ReadHex8();
	if (SkipLine(crc,"Bad crc")) return;
	TX0_WriteHex8(crc);
	crc_data=(crc_data+crc) & 0xFF;
	if (crc_data) {
		TX0_WriteStr(" ## CRC mismatch:");
		TX0_WriteHex8(crc_data);
		};

//	TX0_WriteStr("\r\n");

}	// }}}
TEXT void Xcopy() {	// {{{ copy upto 'X' or 'x'
	TX0_WriteStr("X-mode on:\r\n");
	uint16_t ch;
	ch=0;
	while (((ch & 0x00FF) & ~0x20) != 'X') {
//		smallDelay();	// DELETEME : remove XXX
		ch = RX0_Read();
		if (ch >> 8) {
			TX0_Write(ch);
			if ((ch & 0xFF) == 10) TX0_Write(13);
			if ((ch & 0xFF) == 13) TX0_Write(10);
		};
		
	};
	TX0_WriteStr("X-mode off:\r\n");
}	// }}}
// ========================vvvv setup vvvv========================================= {{{
TEXT void setup(void) {
	usart0_setup();
	DebugLEDs_init();
	ext_addr=0;
	help();
	Attach();
}
// ========================^^^^ setup ^^^^========================================= }}}

TEXT void loop(void) {	// {{{
	uint16_t ch = RX0_Read();
	if (ch >> 8) { // Pokud r25 != 0
		switch(ch & 0xFF) {
			case 10: case 13: 
				TX0_Write(10);
				TX0_Write(13);
				break;
			case 'h': case 'H': case '?':
				help();
				break;
			case 'a': case 'A': 
				Attach();
				break;
			case 'r': case 'R': 
				Release();
				break;
			case 'x': case 'X': 
				Xcopy();
				break;
			case ':':
				IHEX();
				break;
			default:
				TX0_Write('\'');
				TX0_Write((char)(ch & 0xFF)); 
				TX0_Write('\'');
				TX0_Write('?');
				TX0_Write(' ');
			};
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

