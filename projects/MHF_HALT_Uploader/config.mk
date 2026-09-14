PROJECT_NAME :=  MHF_HALT_Uploader
F_CPU := 16000000UL

include $(ROOT_DIR)/mk/mcu/atmega2560.mk
include $(ROOT_DIR)/mk/toolchain.mk

PROJECT_SRC := \
    $(wildcard src/*.c) \
    $(wildcard src/*.S) 
#     src/words/all_words.S \
#     $(wildcard src/tools/*.c) \
#     $(wildcard src/tools/*.S) \
#     $(wildcard src/libs/src/*.c) \
#     $(wildcard src/libs/src/*.S) \

#INC_DIRS += $(ROOT_DIR)/projects/FORTH_c_003/src/libs/include
# vyber varianty knihoven zde
LIBS += Serial.RTS/usart0
# LIBS += Serial.half/usart0

# LIBS += FORTH/FORTH-Engine
# LIBS += FORTH/FORTH-Memory
# LIBS += FORTH/FORTH-Macros
# LIBS += FORTH/FORTH-Defines
# LIBS += FORTH/C_Bats
# LIBS += SD/SD
# LIBS += SD/SD_ard
# LIBS += SD/arduino
LIBS += DebugLEDs/DebugLEDs
# LIBS += bios/StdTextCharDef
# LIBS += bios/SnakeCharDef
# LIBS += bios/SnakeCharDef2
# LIBS += bios/ScanToASCII
# LIBS += bios/TextVGA2
# LIBS += MHF-002/MHF-002
# LIBS += uart/fake
