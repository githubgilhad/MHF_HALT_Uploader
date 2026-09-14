MAKEFLAGS += --no-print-directory --no-builtin-rules

-include $(ROOT_DIR)/mk/colors.mk

MK_DEP += Makefile config.mk $(ROOT_DIR)/mk/*
BUILD_DIR ?= build
OBJ_DIR   := $(BUILD_DIR)/obj
VERSION_H := $(CURDIR)/src/version.h

NO_VGA ?= 0

ifeq ($(NO_VGA),1)
	CFLAGS +=  -DNO_VGA 
endif
BUILD_DATE ?= -DBUILD_DATE=\"$(shell date +"%Y.%m.%d")\"
BUILD_TIME ?= -DBUILD_TIME=\"$(shell date +"%H:%M:%S")\"

CFLAGS += $(BUILD_DATE) $(BUILD_TIME)
CFLAGS += $(OPT) $(CSTD) $(WARN)
CFLAGS += -DF_CPU=$(F_CPU)
CFLAGS += $(addprefix -I,$(INC_DIRS))
CFLAGS_NODEP := $(CFLAGS)
CFLAGS +=  $(DEPFLAGS)

CXXFLAGS += $(BUILD_DATE) $(BUILD_TIME)
CXXFLAGS += $(OPT) $(CXXSTD) $(WARN)
CXXFLAGS += -DF_CPU=$(F_CPU)
CXXFLAGS += $(addprefix -I,$(INC_DIRS))
CXXFLAGS +=  $(DEPFLAGS)

VERBOSE ?= 0

HEAD = @echo -e "$(COLORS)$(BRIGHTMAGENTA)m$@$(COLORS)$(RESET)m:"

ifeq ($(VERBOSE),1)
	Q :=
else
	Q := @
endif
# ----------------------------------------------------
# zdroje
# ----------------------------------------------------

PORT ?=  $(firstword $(wildcard /dev/ttyA-* /dev/ttyAr* /dev/ttyTot* /dev/ttyUSB* /dev/ttyACM* /dev/null) )
SRC_ABS := $(PROJECT_SRC) $(LIB_SRC)

# převedeme na absolutní cesty
SRC_ABS := $(abspath $(SRC_ABS))

# relativní vůči ROOT_DIR (kvůli umístění objektů)
SRC_REL := $(patsubst $(ROOT_DIR)/%,%,$(SRC_ABS))

# objekty
OBJ := $(addprefix $(OBJ_DIR)/,$(SRC_REL))
OBJ := $(OBJ:.c=.o)
OBJ := $(OBJ:.S=.o)
OBJ := $(OBJ:.cpp=.o)

TARGET := $(BUILD_DIR)/$(PROJECT_NAME)

LD_SCRIPT := $(wildcard linker.ld)

# Common flags
LDFLAGS_COMMON ?= -Wl,--relax
#
# If linker.ld exists → add -T linker.ld
ifneq ($(LD_SCRIPT),)
	LDFLAGS += $(LDFLAGS_COMMON) -Wl,-T$(LD_SCRIPT)
else
	LDFLAGS += $(LDFLAGS_COMMON)
endif

all: nums $(TARGET).hex $(TARGET).dis sizecheck TODO tags version
nums:
	$(Q)for i in 1 2 3 4 5 6 7 8 9; do echo "#";done
# ----------------------------------------------------
# linkování
# ----------------------------------------------------

$(TARGET).elf: $(OBJ) 
	$(HEAD)
	$(Q)mkdir -p $(BUILD_DIR)
	$(Q)$(CC) $(LDFLAGS) $^ -o $@ -Wl,-Map=$(TARGET).map
	$(Q)map2sizes.py $(TARGET).map | sort -k 1,1 -k 3,3r -k 6 | sizes2tree.py > $(TARGET).sizes

$(TARGET).hex: $(TARGET).elf $(MK_DEP)
	$(HEAD)
	$(Q)$(OBJCOPY) -O ihex -R .eeprom $< $@

# ----------------------------------------------------
# kompilace C++
# ----------------------------------------------------

$(OBJ_DIR)/%.o: $(ROOT_DIR)/%.cpp $(MK_DEP) | $(VERSION_H)
	$(HEAD)
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CXX) $(CXXFLAGS) -c $< -o $@

# ----------------------------------------------------
# kompilace C
# ----------------------------------------------------

$(OBJ_DIR)/%.o: $(ROOT_DIR)/%.c $(MK_DEP) | $(VERSION_H)
	$(HEAD)
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CC) $(CFLAGS) -c $< -o $@

# ----------------------------------------------------
# kompilace ASM
# ----------------------------------------------------

$(OBJ_DIR)/%.o: $(ROOT_DIR)/%.S $(MK_DEP) | $(VERSION_H)
	$(HEAD)
	$(Q)mkdir -p $(dir $@)
	$(Q)$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)

-include $(OBJ:.o=.d)

.PHONY: all nums clean sizecheck ispload bootloader reset TODO WORDS upload_monitor upload monitor tags debug FORCE version help more_help
FORCE:

help:	## Show help about main commands	{{{
	@egrep -h '(^|[^#])##\s' $(MAKEFILE_LIST) | \
	sed "s/^#	/# /;s/{{{//;s/}}}//" | \
	awk 'BEGIN {FS = ":.*?#[#] "}; {printf "$(shell echo -en $(COLORS))$(BRIGHTGREEN);$(BG_BLUE);$(BOLD)m%-15s$(shell echo -en $(COLORS))$(RESET)m %s\n", $$1, $$2}' 
	@# awk %-15s fits string left, padding with spaces - works better than tabs
# }}}
more_help:	## Show help about all docummented targets {{{
	@egrep -h '###?\s' $(MAKEFILE_LIST) | \
	sed "s/^#	/# /;s/{{{//;s/}}}//" | \
	awk 'BEGIN {FS = ":.*?#[#] "}; {printf "$(shell echo -en $(COLORS))$(BRIGHTGREEN);$(BG_BLUE);$(BOLD)m%-15s$(shell echo -en $(COLORS))$(RESET)m %s\n", $$1, $$2}' 
# }}}


$(TARGET).dis: $(TARGET).elf $(MK_DEP)		### disassemble target
	$(HEAD)
	$(Q)$(OBJDUMP)   --disassemble --source --line-numbers --demangle -z --section=.text  --section=.data   --section=.highram --section=.bss  --section=.rodata --section=.FORTH_data $< > $@
	$(Q)if ( $(OBJDUMP) -h $< | grep -q "\.FORTH_data") ; then \
		$(OBJDUMP) -s -j .FORTH_data  $< >> $@ ; \
	fi
	$(Q)Elf.rb $(TARGET).elf $(TARGET).bin2 $(TARGET).xref2
	$(Q)AVRemu -d -m $(MCU)  -x $(TARGET).xref2 $(TARGET).bin2 >$(TARGET).dis2 || true

sizecheck: $(TARGET).dis ### check size of code and data
	$(HEAD)
	$(Q)avr-size -A $(TARGET).elf | awk ' /\.text/ { text = $$2 } /\.FORTH_data/  { forth = $$2 } /\.data/ { data = $$2 } END {\
		total = text + forth + data;  \
		if (total > 262144) { \
			printf "FLASH overflow: %d bytes (limit 262144)\n", total; \
			exit 1 \
		} else { \
			printf "FLASH used: %d / 262144 bytes\n", total \
		} \
	}'
	$(Q)avr-size $(TARGET).elf $(TARGET).hex |myavrsize.py 
	$(Q)avr-objdump -h $(TARGET).elf | grep -E '\.lowram|\.highram|\.data|\.bss|\.FORTH'|sort -k 2 | awk ' { \
		name = $$2; \
		size_hex = $$3; \
		gsub(/^0x/, "", size_hex); \
		size_dec = strtonum("0x" size_hex); \
		print "\t" size_dec " bytes\t" name; \
		}'


upload: $(TARGET).hex reset sizecheck	## upload code
	/usr/bin/avrdude -v -V -p $(MCU) -D -c wiring -b 115200 -P $(PORT) -U flash:w:$<:i

ispload: $(TARGET).hex sizecheck # upload vias ISP
	/usr/bin/avrdude -v -p atmega2560 -c usbasp -b 115200 -e -U lock:w:0x3F:m -U efuse:w:0xFD:m -U hfuse:w:0xD1:m -U lfuse:w:0xBF:m
	/usr/bin/avrdude -v -p $(MCU) -D -c usbasp -b 115200                 -U flash:w:$<:i

bootloader:	## burn bootloader
	/usr/bin/avrdude -v -p atmega2560 -c usbasp -b 115200 -e -U lock:w:0x3F:m -U efuse:w:0xFD:m -U hfuse:w:0xD0:m -U lfuse:w:0xBF:m
	/usr/bin/avrdude -v -p atmega2560 -c usbasp -b 115200 -U flash:w:/usr/share/arduino/hardware/arduino/avr/bootloaders//stk500v2/stk500boot_v2_mega2560.hex:i

reset:	## reset board
	$(HEAD)
	$(Q) ard-reset-arduino  $(PORT) || true

TODO: $(TARGET).dis  sizecheck ## WORDS	## show TODO and FIXME from code
	$(HEAD)
	$(Q)cd src;grep  --color=always -r "TODO\|FIXME"|grep -v "^.\[[[:digit:]][[:digit:]]m.\[Ktags.\[m.\[K.\[[[:digit:]][[:digit:]]m.\[K:";true

WORDS: $(TARGET).dis  sizecheck		## collects all definitions of words to WORDS.list
	$(HEAD)
	$(Q)find src -name "*.S" -exec grep -h "^DEF" {} \;|sort>WORDS.list

monitor:	## open monitor
	picocom -b 115200 --flow h --noreset -s cat --quiet $(PORT)

upload_monitor: upload monitor	## upload code and open monitor

debug: $(TARGET).dis
	$(HEAD)
	$(Q)AVRe -e  $(TARGET).elf || true

tags:
	ctags -R .


#--------------------------------------------------------------------------------------------------------

# Makro pro získání dat z gitu
GIT_DESCRIBE := $(shell git describe --tags --long 2>/dev/null || echo "v0.0.0-0-g0000000")
GIT_COMMIT_HASH := $(shell git rev-parse --short HEAD)
GIT_COMMIT_MESSAGE := $(shell git log -1 --pretty=%s)

# Cíl pro generování version.h
$(VERSION_H): FORCE
	$(HEAD)
	$(Q)echo "Checking version..."
	$(Q)echo -e "// DO NOT EDIT\n// Autogenerated file\n" >$@.tmp
	$(Q)echo "#pragma once" >>$@.tmp
	$(Q)echo "#define VERSION_STRING \"$(GIT_DESCRIBE)++\"" >>$@.tmp
	$(Q)echo "#define VERSION_COMMIT \"$(GIT_COMMIT_HASH)\"" >>$@.tmp
	$(Q)echo "#define VERSION_MESSAGE \"$(GIT_COMMIT_MESSAGE)\"" >>$@.tmp
	$(Q)$(R_need_target_update)



# Cíl pro návrh nového tagu
new_tag:	## navrhne novy tag v rade
	@LAST_TAG=$$(git tag --sort=-v:refname | head -n1); \
	if [ -z "$$LAST_TAG" ]; then \
		NEW_TAG="v0.0.1"; \
	else \
		IFS=. read -r MAJOR MINOR PATCH <<< "$$(echo $$LAST_TAG | sed 's/^v//')"; \
		PATCH=$$((PATCH + 1)); \
		NEW_TAG="v$${MAJOR}.$${MINOR}.$${PATCH}"; \
	fi; \
	echo "Suggested new tag:"; \
	echo "git tag -a $$NEW_TAG -m \"Release $$NEW_TAG\""; \
	echo "git push origin $$NEW_TAG"

version: $(VERSION_H)	## Cíl pro ruční vygenerování nové verze
