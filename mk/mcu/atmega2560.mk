MCU := atmega2560

CFLAGS  += -mmcu=$(MCU)
CXXFLAGS  += -mmcu=$(MCU)
LDFLAGS += -mmcu=$(MCU)
