/*****************************************************************************
 * epd_port.c — Erlang port binary for Papyrus ePaper driver
 *
 * Protocol (stdin/stdout, all blocking):
 *   Request:  [1 byte cmd][4 bytes payload_len BE][payload_len bytes payload]
 *   Response: [1 byte status: 0=ok,1=err][4 bytes msg_len BE][msg_len bytes msg]
 *
 * Commands:
 *   0x01  init     (no payload)
 *   0x02  display  (2 × PLANE_SIZE bytes: black_plane then red_plane)
 *   0x03  clear    (no payload)
 *   0x04  sleep    (no payload)
 *
 * Display is the Waveshare 12.48" B (black/white/red, 3-colour).
 * Buffer layout: 984 rows × 163 bytes/row = 160,392 bytes per colour plane.
 * CMD_DISPLAY expects both planes concatenated: black_plane <> red_plane.
 *
 * Red plane encoding (Elixir side):
 *   0x00 bytes = no red (white background)
 *   0xFF bytes = red pixels
 * The C driver inverts the red plane before sending it to the panel hardware.
 *****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/select.h>

#include "waveshare/epd12in48/EPD_12in48b.h"
#include "waveshare/epd12in48/DEV_Config.h"

#define CMD_INIT    0x01
#define CMD_DISPLAY 0x02
#define CMD_CLEAR   0x03
#define CMD_SLEEP   0x04

#define STDIN_POLL_TIMEOUT_SEC 1

#define PLANE_SIZE      (163 * 984)          /* 160,392 bytes — one colour plane */
#define DISPLAY_PAYLOAD (2 * PLANE_SIZE)     /* 320,784 bytes — black + red      */

/* Hardware version: 1 = explicit LUT, 2 = OTP waveform (default).
 * Change to 1 if you have an older V1 panel. */
int Version = 2;

/* ---------------------------------------------------------------------------
 * I/O helpers — read/write full buffers from/to stdin/stdout
 * --------------------------------------------------------------------------*/

static int read_exact(uint8_t *buf, size_t len) {
    size_t got = 0;
    while (got < len) {
        ssize_t n = read(STDIN_FILENO, buf + got, len - got);
        if (n <= 0) return -1;
        got += (size_t)n;
    }
    return 0;
}

static int write_exact(const uint8_t *buf, size_t len) {
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = write(STDOUT_FILENO, buf + sent, len - sent);
        if (n <= 0) return -1;
        sent += (size_t)n;
    }
    return 0;
}

/* ---------------------------------------------------------------------------
 * Response helpers
 * --------------------------------------------------------------------------*/

static void send_ok(const char *msg) {
    uint32_t len = (uint32_t)strlen(msg);
    uint8_t hdr[5];
    hdr[0] = 0;                         /* status: ok */
    hdr[1] = (len >> 24) & 0xFF;
    hdr[2] = (len >> 16) & 0xFF;
    hdr[3] = (len >>  8) & 0xFF;
    hdr[4] =  len        & 0xFF;
    write_exact(hdr, 5);
    write_exact((const uint8_t *)msg, len);
}

static void send_error(const char *msg) {
    uint32_t len = (uint32_t)strlen(msg);
    uint8_t hdr[5];
    hdr[0] = 1;                         /* status: error */
    hdr[1] = (len >> 24) & 0xFF;
    hdr[2] = (len >> 16) & 0xFF;
    hdr[3] = (len >>  8) & 0xFF;
    hdr[4] =  len        & 0xFF;
    write_exact(hdr, 5);
    write_exact((const uint8_t *)msg, len);
}

/* ---------------------------------------------------------------------------
 * main loop
 * --------------------------------------------------------------------------*/

int main(void) {
    if (DEV_ModuleInit() != 0) {
        send_error("DEV_ModuleInit failed");
        return 1;
    }

    uint8_t *image_buf = malloc(DISPLAY_PAYLOAD);
    if (!image_buf) {
        send_error("malloc failed");
        return 1;
    }

    for (;;) {
        /* Poll stdin for readability — detects EOF even when idle */
        fd_set rfds;
        struct timeval tv;
        int sel_ret;

        for (;;) {
            FD_ZERO(&rfds);
            FD_SET(STDIN_FILENO, &rfds);
            tv.tv_sec = STDIN_POLL_TIMEOUT_SEC;
            tv.tv_usec = 0;

            sel_ret = select(STDIN_FILENO + 1, &rfds, NULL, NULL, &tv);
            if (sel_ret < 0) {
                /* select error (e.g., EINTR from signal) — treat as fatal */
                goto cleanup;
            }
            if (sel_ret > 0) {
                break;  /* stdin is readable — proceed to read_exact */
            }
            /* sel_ret == 0: timeout — loop back to poll again */
        }

        /* Read 5-byte header: [1 cmd][4 payload_len BE] */
        uint8_t hdr[5];
        if (read_exact(hdr, 5) != 0) {
            /* stdin closed — normal exit */
            goto cleanup;
        }

        uint8_t  cmd = hdr[0];
        uint32_t payload_len = ((uint32_t)hdr[1] << 24)
                             | ((uint32_t)hdr[2] << 16)
                             | ((uint32_t)hdr[3] <<  8)
                             |  (uint32_t)hdr[4];

        /* Read payload */
        if (payload_len > DISPLAY_PAYLOAD) {
            send_error("payload too large");
            continue;
        }
        if (payload_len > 0) {
            if (read_exact(image_buf, payload_len) != 0) {
                goto cleanup;
            }
        }

        /* Dispatch */
        switch (cmd) {
            case CMD_INIT:
                if (EPD_12in48B_Init() == 0) {
                    send_ok("ok");
                } else {
                    send_error("EPD_12in48B_Init failed");
                }
                break;

            case CMD_DISPLAY:
                if (payload_len != DISPLAY_PAYLOAD) {
                    send_error("display: expected 2 x plane_size bytes (black + red planes)");
                    break;
                }
                EPD_12in48B_Display(image_buf, image_buf + PLANE_SIZE);
                send_ok("ok");
                break;

            case CMD_CLEAR:
                EPD_12in48B_Clear();
                send_ok("ok");
                break;

            case CMD_SLEEP:
                EPD_12in48B_Sleep();
                send_ok("ok");
                break;

            default:
                send_error("unknown command");
                break;
        }
    }

cleanup:
    free(image_buf);
    DEV_ModuleExit();
    return 0;
}
