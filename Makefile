# Makefile — mdserve build system
#
# macOS prerequisite: brew install argp-standalone

UNAME_S := $(shell uname -s)

PREFIX ?= /usr/local
MANPREFIX ?= $(PREFIX)/share/man
STRIP ?= strip
INSTALL ?= install
CURL ?= curl -fsSL

# Convert targets to flags for backwards compatibility
O_DEBUG := 0  ## Debug binary (1 = debug,   0 = release)

ifeq ($(strip $(O_DEBUG)),1)
	CFLAGS += -g3 -DDEBUG

	LDFLAGS += -fsanitize=address -fsanitize=undefined
	CFLAGS  += -fstack-usage \
	          -fsanitize=address \
	          -fsanitize=undefined

    ifneq (,$(findstring clang,$(CC)))
		CFLAGS += -ffreestanding
    endif
else
	CFLAGS += -O3
endif

# Platform-specific settings
ifeq ($(UNAME_S),Darwin)
	# macOS: need argp from Homebrew (brew install argp-standalone)
	LDLIBS += -largp
else
	# Linux: _GNU_SOURCE for strptime, etc.
	CFLAGS += -D_GNU_SOURCE
endif

BUILD       =  build
BIN         =  mdserve


# cJSON (mandatory — always downloaded, built, and linked)
CJSON_DIR     =  third_party/cJson
CJSON_GITHUB  =  https://raw.githubusercontent.com/DaveGamble/cJSON/refs/tags/v1.7.19


FRONT_END_FILES = \
    front_end/javascript/main.js \
    front_end/stylesheet/style.css \
    front_end/stylesheet/themes/light.css \
    front_end/favicon.ico \
    front_end/index.html

FRONT_END_SCRIPT       = front_end/embed_frontend.bash
FRONT_END_GENERATED_C  = $(BUILD)/gen_embedded_front_end_dir.c
EMBD_FRONT_END_H       = src/embd_front_end.h
FRONT_END_GENERATED_O  = $(BUILD)/gen_embedded_front_end_dir.o

# Compiler warnings
CFLAGS +=  -Wshadow -Wconversion \
           -Wall -Wextra -Wpedantic \
           -Wno-missing-field-initializers \
           -Wstrict-prototypes -Wmissing-prototypes

# Common flags
CFLAGS +=  -Isrc -std=c17
LDLIBS +=  -lpthread

# Source files
SRC      := $(wildcard src/*.c)
OUT       = $(SRC:%.c=$(BUILD)/%.o)
DEP       = $(OUT:.o=.d)

# cJSON — mandatory, always built and linked
CFLAGS += -I$(CJSON_DIR)
OUT    += $(BUILD)/$(CJSON_DIR)/cJSON.o $(BUILD)/$(CJSON_DIR)/cJSON_Utils.o

all: $(BIN)

help:  ## Show this help
	@echo "Variable:"
	@awk 'BEGIN {FS="  ## "} \
		/^O_[a-zA-Z_]+[[:space:]]*:=/ { \
		split($$1, a, /[[:space:]]*:=/); \
		printf "  \033[36m%-20s\033[0m %s\n", a[1], $$2; \
	}' $(MAKEFILE_LIST)

	@echo
	@echo "Targets:"
	@grep -hE '^[a-zA-Z_-]+:.*  ## ' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS="  ## "}; {printf "  \033[33m%-20s\033[0m %s\n", $$1, $$2}'

	@echo
	@echo "cJSON (mandatory — downloads automatically on any build):"
	@echo "  make download-cjson       # Download cJSON files only"

$(BUILD):  ## Create build directories automatically
	mkdir -p $(BUILD)

$(BUILD)/%.o: %.c | $(EMBD_FRONT_END_H) $(CJSON_DIR)/cJSON.h $(CJSON_DIR)/cJSON_Utils.h
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

# Pull in the compiler-generated per-file header dependencies (created above
# via -MMD -MP). This is what makes "only the .c file(s) that actually
# #include gen_embedded_front_end_dir.h get rebuilt when it changes" true —
# without it, the order-only prerequisite above would correctly avoid a full
# rebuild, but the one real consumer wouldn't rebuild either.
-include $(DEP)

# Regenerate when any frontend file or the script itself changes
$(FRONT_END_GENERATED_C): $(FRONT_END_FILES) $(FRONT_END_SCRIPT)
	@OUT_C_FILE="$(FRONT_END_GENERATED_C)" \
	OUT_H_FILE="$(EMBD_FRONT_END_H)" \
	TARGET_FILES="$(FRONT_END_FILES)" \
	bash $(FRONT_END_SCRIPT)

$(EMBD_FRONT_END_H): $(FRONT_END_GENERATED_C)
	@# Header is generated as side-effect of .c generation

$(FRONT_END_GENERATED_O): $(FRONT_END_GENERATED_C)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $(FRONT_END_GENERATED_C) -o $@

# ── cJSON rules (mandatory) ──────────────────────────────────────────────────

$(CJSON_DIR):
	mkdir -p $(CJSON_DIR)

$(CJSON_DIR)/cJSON.c: | $(CJSON_DIR)
	$(CURL) -o $@ $(CJSON_GITHUB)/cJSON.c

$(CJSON_DIR)/cJSON.h: | $(CJSON_DIR)
	$(CURL) -o $@ $(CJSON_GITHUB)/cJSON.h

$(CJSON_DIR)/cJSON_Utils.c: | $(CJSON_DIR)
	$(CURL) -o $@ $(CJSON_GITHUB)/cJSON_Utils.c

$(CJSON_DIR)/cJSON_Utils.h: | $(CJSON_DIR)
	$(CURL) -o $@ $(CJSON_GITHUB)/cJSON_Utils.h

# Explicit rules (not a pattern) so the generic $(BUILD)/%.o rule can't shadow
# them. Two separate objects — unlike cJSON isn't amalgamation-style;
# cJSON_Utils.c calls into cJSON's own functions rather than #including it,
# so both objects need to exist and both get linked into the final binary.
$(BUILD)/$(CJSON_DIR)/cJSON.o: $(CJSON_DIR)/cJSON.c $(CJSON_DIR)/cJSON.h | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -w -MMD -MP -c $(CJSON_DIR)/cJSON.c -o $@

$(BUILD)/$(CJSON_DIR)/cJSON_Utils.o: $(CJSON_DIR)/cJSON_Utils.c $(CJSON_DIR)/cJSON_Utils.h $(CJSON_DIR)/cJSON.h | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -w -MMD -MP -c $(CJSON_DIR)/cJSON_Utils.c -o $@

download-cjson:  ## Download the cJSON sources into third_party/ without building
download-cjson: $(CJSON_DIR)/cJSON.c $(CJSON_DIR)/cJSON.h $(CJSON_DIR)/cJSON_Utils.c $(CJSON_DIR)/cJSON_Utils.h
	@echo "cJSON files downloaded to $(CJSON_DIR)/"

clean-cjson:  ## Remove downloaded cJSON sources and their build objects
	$(RM) -rf $(CJSON_DIR) $(BUILD)/$(CJSON_DIR)

# ── Build targets ────────────────────────────────────────────────────────────

$(BIN): $(OUT) $(FRONT_END_GENERATED_O) ## Build the mdserve binary
	$(CC) $(LDFLAGS) -o $@ $(OUT) $(FRONT_END_GENERATED_O) $(LDLIBS)

debug:  ## Build the debug binary — run `make debug`
	$(MAKE) $(BIN) O_DEBUG=1

install: all  ## Install the mdserve binary
	$(INSTALL) -m 0755 -d $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

	$(INSTALL) -m 0755 -d $(DESTDIR)$(MANPREFIX)/man1
	$(INSTALL) -m 0755 mdserve.1 $(DESTDIR)$(MANPREFIX)/man1/$(BIN).1

clean:  ## Clean up build artifacts
	$(RM) -rf $(BUILD)/src/* $(BIN)

uninstall:  ## Uninstall the mdserve binary
	$(RM) $(DESTDIR)$(PREFIX)/bin/$(BIN)
	$(RM)$(DESTDIR)$(MANPREFIX)/man1/$(BIN).1

strip: $(BIN)  ## Strip the mdserve binary
	$(STRIP) $^

.PHONY: all help install uninstall strip clean debug clean-cjson download-cjson
