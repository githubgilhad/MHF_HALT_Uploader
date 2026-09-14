CC      := avr-gcc
CXX     := avr-g++
AR      := avr-ar
OBJCOPY := avr-objcopy
SIZE    := avr-size
OBJDUMP  := avr-objdump

OPT := -Os
CSTD := -std=gnu11
CXXSTD := -std=gnu++17 -fno-exceptions -fno-rtti -fno-threadsafe-statics -fno-use-cxa-atexit
#		-fno-exceptions → žádné výjimky (velká úspora)
#		-fno-rtti → žádné dynamic_cast, typeid
#		-fno-threadsafe-statics → menší init kód
#		-fno-use-cxa-atexit → žádné destruktory na konci programu
WARN := -Wall -Wextra

DEPFLAGS := -MMD -MP
