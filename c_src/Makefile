# Papyrus — C port Makefile
# Builds priv/epd_port on Linux/Raspberry Pi (requires liblgpio-dev)
# On non-Linux platforms (e.g. macOS for development), compilation is skipped
# and a stub placeholder is written so Mix can find the priv directory.

CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra
CFLAGS += -I waveshare/epd12in48
LDFLAGS += -llgpio -lrt

# elixir_make sets MIX_APP_PATH; PRIV_DIR falls back for manual builds
PRIV_DIR ?= $(MIX_APP_PATH)/priv
TARGET = $(PRIV_DIR)/epd_port

SRCS = epd_port.c \
       waveshare/epd12in48/EPD_12in48b.c \
       waveshare/epd12in48/DEV_Config.c

UNAME_S := $(shell uname -s)

.PHONY: all clean

ifeq ($(UNAME_S),Linux)
all: $(PRIV_DIR) $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
else
all: $(PRIV_DIR)
	@echo "Skipping C port compilation on $(UNAME_S): lgpio is Linux/Raspberry Pi only"
	@touch $(PRIV_DIR)/.epd_port_stub
endif

$(PRIV_DIR):
	mkdir -p $(PRIV_DIR)

clean:
	rm -f $(TARGET)
