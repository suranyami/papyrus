# Papyrus — C port Makefile
# Builds priv/epd_port on Linux/Raspberry Pi (requires liblgpio-dev)

CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra
CFLAGS += -I waveshare/epd12in48
LDFLAGS += -llgpio

# elixir_make sets MIX_APP_PATH; PRIV_DIR falls back for manual builds
PRIV_DIR ?= $(MIX_APP_PATH)/priv
TARGET = $(PRIV_DIR)/epd_port

SRCS = epd_port.c \
       waveshare/epd12in48/EPD_12in48.c \
       waveshare/epd12in48/DEV_Config.c

.PHONY: all clean

all: $(PRIV_DIR) $(TARGET)

$(PRIV_DIR):
	mkdir -p $(PRIV_DIR)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET)
