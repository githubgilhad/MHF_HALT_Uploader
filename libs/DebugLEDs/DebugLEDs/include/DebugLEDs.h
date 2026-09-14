/* vim: ft=cpp showbreak=--»\  noexpandtab fileencoding=utf-8 nomodified wrap textwidth=0 foldmethod=marker foldmarker={{{,}}} foldcolumn=4 ruler showcmd lcs=tab\:|- list: tabstop=8 linebreak tags=./tags;,tags; 
 * */
// ,,g = gcc, exactly one space after "set"
//
#pragma once

void DebugLEDs_init();
void DebugLEDs_setRGB(uint8_t led, uint8_t Red, uint8_t Green, uint8_t Blue);
void DebugLEDs_show();
//
typedef struct rgb_color {
  unsigned char red, green, blue;
} rgb_color;
//
extern rgb_color DebugLEDs_values[6];
//
/*
rgb_color *get_rgb_color(uint8_t r, uint8_t g, uint8_t b) {
  static rgb_color c;
  c = (struct rgb_color){r, g, b};
  return &c;
};
*/
