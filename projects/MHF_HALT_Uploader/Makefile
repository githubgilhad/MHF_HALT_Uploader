MAKEFLAGS += --no-print-directory --no-builtin-rules
ROOT_DIR := $(abspath ../..)
MK_DEP += linker.ld
include config.mk
include $(ROOT_DIR)/mk/libs.mk
include $(ROOT_DIR)/mk/rules.mk

# Recipe R_need_target_update {{{
R_need_target_update = \
	if cmp -s $@ $@.tmp &>/dev/null ; then \
		rm -f $@.tmp; \
		echo -e "$(COLORS)$(BRIGHTYELLOW);$(BG_GREEN)m$@$(COLORS)$(RESET)m - is OK"; \
	else \
		mv $@.tmp $@; \
		echo -e "$(COLORS)$(BRIGHTCYAN);$(BG_BLUE)m$@$(COLORS)$(RESET)m - updated"; \
	fi
# }}}

INC_FILES := $(wildcard src/words/*/*)



# -----------------------------------------------------
# Objekt závisí na generovaném souboru
# -----------------------------------------------------
# $(OBJ_DIR)/src/words/all_words.o: src/words/all_words.S $(INC_FILES) | $(OBJ_DIR)/src/words/
# 	@mkdir -p $(dir $@)
# 	$(CC) $(ASFLAGS) -c $< -o $@
# 
# $(OBJ_DIR)/src/words/:
# 	@mkdir -p $@

