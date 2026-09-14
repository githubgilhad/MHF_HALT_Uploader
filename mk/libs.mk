define include_lib
include $(ROOT_DIR)/libs/$(1)/lib.mk
endef

$(foreach L,$(LIBS),$(eval $(call include_lib,$(L))))
