/*****************************************************************************
* | File        :   EPD_12in48b.c
* | Author      :   Waveshare team
* | Function    :   Electronic paper driver
* | Info        :
*----------------
* | This version:   V1.1
* | Date        :   2022-09-13
* | Info        :   Added support for V2
*
* Papyrus fixes applied over reference source:
*   - EPD_M1_ReadBusy: while(0) corrected to while(busy)
*   - EPD_M1_ReadTemperature: printf changed to fprintf(stderr) to avoid
*     corrupting the Erlang port protocol pipe on stdout
*   - All ReadBusy functions: added BUSY_TIMEOUT_MS deadline to prevent
*     infinite spin when a panel BUSY pin does not clear (e.g. cold boot,
*     prior run crashed mid-refresh). Returns -1 on timeout so callers
*     can propagate a meaningful error rather than hanging indefinitely.
******************************************************************************/
#include "EPD_12in48b.h"
#include "Debug.h"
#include <stdio.h>
#include <time.h>

extern int Version;

/* Maximum time (ms) to wait for any panel BUSY pin to de-assert.
 * A full display refresh on the 12.48" panel takes up to ~20 seconds.
 * 25 seconds leaves headroom below the 30-second Elixir-side timeout
 * so we get a descriptive error rather than a generic timeout. */
#define BUSY_TIMEOUT_MS 25000

static void EPD_Reset(void);
static void EPD_M1_SendCommand(UBYTE Reg);
static void EPD_M1_SendData(UBYTE Data);
static void EPD_S1_SendCommand(UBYTE Reg);
static void EPD_S1_SendData(UBYTE Data);
static void EPD_M2_SendCommand(UBYTE Reg);
static void EPD_M2_SendData(UBYTE Data);
static void EPD_S2_SendCommand(UBYTE Reg);
static void EPD_S2_SendData(UBYTE Data);
static void EPD_M1M2_SendCommand(UBYTE Reg);
static void EPD_M1S1M2S2_SendCommand(UBYTE Reg);
static void EPD_M1S1M2S2_SendData(UBYTE Data);
/* Return 0 if busy clears within BUSY_TIMEOUT_MS, -1 on timeout */
static int EPD_M1_ReadBusy(void);
static int EPD_M2_ReadBusy(void);
static int EPD_S1_ReadBusy(void);
static int EPD_S2_ReadBusy(void);
/* Returns 0 on success, -1 if M1 busy timed out during temperature read */
static int EPD_M1_ReadTemperature(void);
static void EPD_SetLut(void);

int EPD_12in48B_Init(void)
{
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
    DEV_Digital_Write(EPD_S1_CS_PIN, 1);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
    DEV_Digital_Write(EPD_S2_CS_PIN, 1);

    EPD_Reset();

    if (Version == 1) {
        EPD_M1_SendCommand(0x00);
        EPD_M1_SendData(0x2f);
        EPD_S1_SendCommand(0x00);
        EPD_S1_SendData(0x2f);
        EPD_M2_SendCommand(0x00);
        EPD_M2_SendData(0x23);
        EPD_S2_SendCommand(0x00);
        EPD_S2_SendData(0x23);

        EPD_M1_SendCommand(0x01);
        EPD_M1_SendData(0x07);
        EPD_M1_SendData(0x17);
        EPD_M1_SendData(0x3F);
        EPD_M1_SendData(0x3F);
        EPD_M1_SendData(0x0d);
        EPD_M2_SendCommand(0x01);
        EPD_M2_SendData(0x07);
        EPD_M2_SendData(0x17);
        EPD_M2_SendData(0x3F);
        EPD_M2_SendData(0x3F);
        EPD_M2_SendData(0x0d);

        EPD_M1_SendCommand(0x06);
        EPD_M1_SendData(0x17);
        EPD_M1_SendData(0x17);
        EPD_M1_SendData(0x39);
        EPD_M1_SendData(0x17);
        EPD_M2_SendCommand(0x06);
        EPD_M2_SendData(0x17);
        EPD_M2_SendData(0x17);
        EPD_M2_SendData(0x39);
        EPD_M2_SendData(0x17);

        EPD_M1_SendCommand(0x61);
        EPD_M1_SendData(0x02);
        EPD_M1_SendData(0x88);
        EPD_M1_SendData(0x01);
        EPD_M1_SendData(0xEC);
        EPD_S1_SendCommand(0x61);
        EPD_S1_SendData(0x02);
        EPD_S1_SendData(0x90);
        EPD_S1_SendData(0x01);
        EPD_S1_SendData(0xEC);
        EPD_M2_SendCommand(0x61);
        EPD_M2_SendData(0x02);
        EPD_M2_SendData(0x90);
        EPD_M2_SendData(0x01);
        EPD_M2_SendData(0xEC);
        EPD_S2_SendCommand(0x61);
        EPD_S2_SendData(0x02);
        EPD_S2_SendData(0x88);
        EPD_S2_SendData(0x01);
        EPD_S2_SendData(0xEC);

        EPD_M1S1M2S2_SendCommand(0x15);
        EPD_M1S1M2S2_SendData(0x20);
        EPD_M1S1M2S2_SendCommand(0x30);
        EPD_M1S1M2S2_SendData(0x08);
        EPD_M1S1M2S2_SendCommand(0x50);
        EPD_M1S1M2S2_SendData(0x31);
        EPD_M1S1M2S2_SendData(0x07);
        EPD_M1S1M2S2_SendCommand(0x60);
        EPD_M1S1M2S2_SendData(0x22);

        EPD_M1_SendCommand(0xE0);
        EPD_M1_SendData(0x01);
        EPD_M2_SendCommand(0xE0);
        EPD_M2_SendData(0x01);
        EPD_M1S1M2S2_SendCommand(0xE3);
        EPD_M1S1M2S2_SendData(0x00);
        EPD_M1_SendCommand(0x82);
        EPD_M1_SendData(0x1c);
        EPD_M2_SendCommand(0x82);
        EPD_M2_SendData(0x1c);

        EPD_SetLut();
    }
    else if (Version == 2) {
        EPD_M1_SendCommand(0x00);
        EPD_M1_SendData(0x0f);
        EPD_S1_SendCommand(0x00);
        EPD_S1_SendData(0x0f);
        EPD_M2_SendCommand(0x00);
        EPD_M2_SendData(0x03);
        EPD_S2_SendCommand(0x00);
        EPD_S2_SendData(0x03);

        EPD_M1_SendCommand(0x06);
        EPD_M1_SendData(0x17);
        EPD_M1_SendData(0x17);
        EPD_M1_SendData(0x39);
        EPD_M1_SendData(0x17);
        EPD_M2_SendCommand(0x06);
        EPD_M2_SendData(0x17);
        EPD_M2_SendData(0x17);
        EPD_M2_SendData(0x39);
        EPD_M2_SendData(0x17);

        EPD_M1_SendCommand(0x61);
        EPD_M1_SendData(0x02);
        EPD_M1_SendData(0x88);
        EPD_M1_SendData(0x01);
        EPD_M1_SendData(0xEC);
        EPD_S1_SendCommand(0x61);
        EPD_S1_SendData(0x02);
        EPD_S1_SendData(0x90);
        EPD_S1_SendData(0x01);
        EPD_S1_SendData(0xEC);
        EPD_M2_SendCommand(0x61);
        EPD_M2_SendData(0x02);
        EPD_M2_SendData(0x90);
        EPD_M2_SendData(0x01);
        EPD_M2_SendData(0xEC);
        EPD_S2_SendCommand(0x61);
        EPD_S2_SendData(0x02);
        EPD_S2_SendData(0x88);
        EPD_S2_SendData(0x01);
        EPD_S2_SendData(0xEC);

        EPD_M1S1M2S2_SendCommand(0x15);
        EPD_M1S1M2S2_SendData(0x20);
        EPD_M1S1M2S2_SendCommand(0x50);
        EPD_M1S1M2S2_SendData(0x11);
        EPD_M1S1M2S2_SendData(0x07);
        EPD_M1S1M2S2_SendCommand(0x60);
        EPD_M1S1M2S2_SendData(0x22);
        EPD_M1S1M2S2_SendCommand(0xE3);
        EPD_M1S1M2S2_SendData(0x00);

        if (EPD_M1_ReadTemperature() != 0) {
            return -1;
        }
    }
    return 0;
}

int EPD_12in48B_Clear(void)
{
    UWORD y, x;

    // M1 part 648*492 (bottom-left)
    EPD_M1_SendCommand(0x10);
    for(y = 492; y < 984; y++)
        for(x = 0; x < 81; x++)
            EPD_M1_SendData(0xff);
    EPD_M1_SendCommand(0x13);
    for(y = 492; y < 984; y++)
        for(x = 0; x < 81; x++)
            EPD_M1_SendData(0x00);

    // S1 part 656*492 (bottom-right)
    EPD_S1_SendCommand(0x10);
    for(y = 492; y < 984; y++)
        for(x = 81; x < 163; x++)
            EPD_S1_SendData(0xff);
    EPD_S1_SendCommand(0x13);
    for(y = 492; y < 984; y++)
        for(x = 81; x < 163; x++)
            EPD_S1_SendData(0x00);

    // M2 part 656*492 (top-right)
    EPD_M2_SendCommand(0x10);
    for(y = 0; y < 492; y++)
        for(x = 81; x < 163; x++)
            EPD_M2_SendData(0xff);
    EPD_M2_SendCommand(0x13);
    for(y = 0; y < 492; y++)
        for(x = 81; x < 163; x++)
            EPD_M2_SendData(0x00);

    // S2 part 648*492 (top-left)
    EPD_S2_SendCommand(0x10);
    for(y = 0; y < 492; y++)
        for(x = 0; x < 81; x++)
            EPD_S2_SendData(0xff);
    EPD_S2_SendCommand(0x13);
    for(y = 0; y < 492; y++)
        for(x = 0; x < 81; x++)
            EPD_S2_SendData(0x00);

    return EPD_12in48B_TurnOnDisplay();
}

int EPD_12in48B_Display(const UBYTE *BlackImage, const UBYTE *RedImage)
{
    int x, y;

    // S2: top-left 648*492
    EPD_S2_SendCommand(0x10);
    for(y = 0; y < 492; y++)
        for(x = 0; x < 81; x++)
            EPD_S2_SendData(*(BlackImage + (y*163 + x)));
    EPD_S2_SendCommand(0x13);
    for(y = 0; y < 492; y++)
        for(x = 0; x < 81; x++)
            EPD_S2_SendData(*(RedImage + (y*163 + x)));

    // M2: top-right 656*492
    EPD_M2_SendCommand(0x10);
    for(y = 0; y < 492; y++)
        for(x = 81; x < 163; x++)
            EPD_M2_SendData(*(BlackImage + (y*163 + x)));
    EPD_M2_SendCommand(0x13);
    for(y = 0; y < 492; y++)
        for(x = 81; x < 163; x++)
            EPD_M2_SendData(*(RedImage + (y*163 + x)));

    // S1: bottom-right 656*492
    EPD_S1_SendCommand(0x10);
    for(y = 492; y < 984; y++)
        for(x = 81; x < 163; x++)
            EPD_S1_SendData(*(BlackImage + (y*163 + x)));
    EPD_S1_SendCommand(0x13);
    for(y = 492; y < 984; y++)
        for(x = 81; x < 163; x++)
            EPD_S1_SendData(*(RedImage + (y*163 + x)));

    // M1: bottom-left 648*492
    EPD_M1_SendCommand(0x10);
    for(y = 492; y < 984; y++)
        for(x = 0; x < 81; x++)
            EPD_M1_SendData(*(BlackImage + (y*163 + x)));
    EPD_M1_SendCommand(0x13);
    for(y = 492; y < 984; y++)
        for(x = 0; x < 81; x++)
            EPD_M1_SendData(*(RedImage + (y*163 + x)));

    return EPD_12in48B_TurnOnDisplay();
}

int EPD_12in48B_TurnOnDisplay(void)
{
    EPD_M1M2_SendCommand(0x04);  // power on
    DEV_Delay_ms(300);
    EPD_M1S1M2S2_SendCommand(0x12);  // display refresh
    if (EPD_M1_ReadBusy() != 0) return -1;
    if (EPD_S1_ReadBusy() != 0) return -1;
    if (EPD_M2_ReadBusy() != 0) return -1;
    if (EPD_S2_ReadBusy() != 0) return -1;
    return 0;
}

void EPD_12in48B_Sleep(void)
{
    EPD_M1S1M2S2_SendCommand(0x02);  // power off
    DEV_Delay_ms(300);
    EPD_M1S1M2S2_SendCommand(0x07);  // deep sleep
    EPD_M1S1M2S2_SendData(0xA5);
    DEV_Delay_ms(300);
}

static void EPD_Reset(void)
{
    DEV_Digital_Write(EPD_M1S1_RST_PIN, 1);
    DEV_Digital_Write(EPD_M2S2_RST_PIN, 1);
    DEV_Delay_ms(200);
    DEV_Digital_Write(EPD_M1S1_RST_PIN, 0);
    DEV_Digital_Write(EPD_M2S2_RST_PIN, 0);
    DEV_Delay_ms(10);
    DEV_Digital_Write(EPD_M1S1_RST_PIN, 1);
    DEV_Digital_Write(EPD_M2S2_RST_PIN, 1);
    DEV_Delay_ms(200);
}

static void EPD_M1_SendCommand(UBYTE Reg)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 0);
    DEV_Digital_Write(EPD_M1_CS_PIN, 0);
    DEV_SPI_WriteByte(Reg);
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
}
static void EPD_M1_SendData(UBYTE Data)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 1);
    DEV_Digital_Write(EPD_M1_CS_PIN, 0);
    DEV_SPI_WriteByte(Data);
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
}
static void EPD_S1_SendCommand(UBYTE Reg)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 0);
    DEV_Digital_Write(EPD_S1_CS_PIN, 0);
    DEV_SPI_WriteByte(Reg);
    DEV_Digital_Write(EPD_S1_CS_PIN, 1);
}
static void EPD_S1_SendData(UBYTE Data)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 1);
    DEV_Digital_Write(EPD_S1_CS_PIN, 0);
    DEV_SPI_WriteByte(Data);
    DEV_Digital_Write(EPD_S1_CS_PIN, 1);
}
static void EPD_M2_SendCommand(UBYTE Reg)
{
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 0);
    DEV_Digital_Write(EPD_M2_CS_PIN, 0);
    DEV_SPI_WriteByte(Reg);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
}
static void EPD_M2_SendData(UBYTE Data)
{
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 1);
    DEV_Digital_Write(EPD_M2_CS_PIN, 0);
    DEV_SPI_WriteByte(Data);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
}
static void EPD_S2_SendCommand(UBYTE Reg)
{
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 0);
    DEV_Digital_Write(EPD_S2_CS_PIN, 0);
    DEV_SPI_WriteByte(Reg);
    DEV_Digital_Write(EPD_S2_CS_PIN, 1);
}
static void EPD_S2_SendData(UBYTE Data)
{
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 1);
    DEV_Digital_Write(EPD_S2_CS_PIN, 0);
    DEV_SPI_WriteByte(Data);
    DEV_Digital_Write(EPD_S2_CS_PIN, 1);
}
static void EPD_M1M2_SendCommand(UBYTE Reg)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 0);
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 0);
    DEV_Digital_Write(EPD_M1_CS_PIN, 0);
    DEV_Digital_Write(EPD_M2_CS_PIN, 0);
    DEV_SPI_WriteByte(Reg);
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
}
static void EPD_M1S1M2S2_SendCommand(UBYTE Reg)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 0);
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 0);
    DEV_Digital_Write(EPD_M1_CS_PIN, 0);
    DEV_Digital_Write(EPD_S1_CS_PIN, 0);
    DEV_Digital_Write(EPD_M2_CS_PIN, 0);
    DEV_Digital_Write(EPD_S2_CS_PIN, 0);
    DEV_SPI_WriteByte(Reg);
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
    DEV_Digital_Write(EPD_S1_CS_PIN, 1);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
    DEV_Digital_Write(EPD_S2_CS_PIN, 1);
}
static void EPD_M1S1M2S2_SendData(UBYTE Data)
{
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 1);
    DEV_Digital_Write(EPD_M2S2_DC_PIN, 1);
    DEV_Digital_Write(EPD_M1_CS_PIN, 0);
    DEV_Digital_Write(EPD_S1_CS_PIN, 0);
    DEV_Digital_Write(EPD_M2_CS_PIN, 0);
    DEV_Digital_Write(EPD_S2_CS_PIN, 0);
    DEV_SPI_WriteByte(Data);
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
    DEV_Digital_Write(EPD_S1_CS_PIN, 1);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
    DEV_Digital_Write(EPD_S2_CS_PIN, 1);
}

/* Helper: current time in milliseconds (monotonic) */
static long now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long)(ts.tv_sec * 1000L + ts.tv_nsec / 1000000L);
}

/* FIX: reference code had while(0) here — corrected to while(busy).
 * FIX: added BUSY_TIMEOUT_MS deadline to prevent unbounded spin. */
static int EPD_M1_ReadBusy(void)
{
    UBYTE busy;
    long deadline = now_ms() + BUSY_TIMEOUT_MS;
    do {
        EPD_M1_SendCommand(0x71);
        busy = DEV_Digital_Read(EPD_M1_BUSY_PIN);
        busy = !(busy & 0x01);
        if (busy && now_ms() >= deadline) {
            fprintf(stderr, "EPD_M1_ReadBusy: BUSY pin did not clear within %dms\n", BUSY_TIMEOUT_MS);
            return -1;
        }
    } while(busy);
    Debug("M1 Busy free\r\n");
    DEV_Delay_ms(200);
    return 0;
}
static int EPD_M2_ReadBusy(void)
{
    UBYTE busy;
    long deadline = now_ms() + BUSY_TIMEOUT_MS;
    do {
        EPD_M2_SendCommand(0x71);
        busy = DEV_Digital_Read(EPD_M2_BUSY_PIN);
        busy = !(busy & 0x01);
        if (busy && now_ms() >= deadline) {
            fprintf(stderr, "EPD_M2_ReadBusy: BUSY pin did not clear within %dms\n", BUSY_TIMEOUT_MS);
            return -1;
        }
    } while(busy);
    Debug("M2 Busy free\r\n");
    DEV_Delay_ms(200);
    return 0;
}
static int EPD_S1_ReadBusy(void)
{
    UBYTE busy;
    long deadline = now_ms() + BUSY_TIMEOUT_MS;
    do {
        EPD_S1_SendCommand(0x71);
        busy = DEV_Digital_Read(EPD_S1_BUSY_PIN);
        busy = !(busy & 0x01);
        if (busy && now_ms() >= deadline) {
            fprintf(stderr, "EPD_S1_ReadBusy: BUSY pin did not clear within %dms\n", BUSY_TIMEOUT_MS);
            return -1;
        }
    } while(busy);
    Debug("S1 Busy free\r\n");
    DEV_Delay_ms(200);
    return 0;
}
static int EPD_S2_ReadBusy(void)
{
    UBYTE busy;
    long deadline = now_ms() + BUSY_TIMEOUT_MS;
    do {
        EPD_S2_SendCommand(0x71);
        busy = DEV_Digital_Read(EPD_S2_BUSY_PIN);
        busy = !(busy & 0x01);
        if (busy && now_ms() >= deadline) {
            fprintf(stderr, "EPD_S2_ReadBusy: BUSY pin did not clear within %dms\n", BUSY_TIMEOUT_MS);
            return -1;
        }
    } while(busy);
    Debug("S2 Busy free\r\n");
    DEV_Delay_ms(200);
    return 0;
}

/* FIX: printf changed to fprintf(stderr) — stdout is the Erlang port pipe */
static int EPD_M1_ReadTemperature(void)
{
    EPD_M1_SendCommand(0x40);
    if (EPD_M1_ReadBusy() != 0) {
        return -1;
    }
    DEV_Delay_ms(300);

    DEV_Digital_Write(EPD_M1_CS_PIN, 0);
    DEV_Digital_Write(EPD_S1_CS_PIN, 1);
    DEV_Digital_Write(EPD_M2_CS_PIN, 1);
    DEV_Digital_Write(EPD_S2_CS_PIN, 1);
    DEV_Digital_Write(EPD_M1S1_DC_PIN, 1);
    DEV_Delay_us(5);

    UBYTE temp = DEV_SPI_ReadByte(0x00);
    DEV_Digital_Write(EPD_M1_CS_PIN, 1);
    fprintf(stderr, "Read Temperature Reg:%d\r\n", temp);

    EPD_M1S1M2S2_SendCommand(0xe0);
    EPD_M1S1M2S2_SendData(0x03);
    EPD_M1S1M2S2_SendCommand(0xe5);
    EPD_M1S1M2S2_SendData(temp);
    return 0;
}

static unsigned char lut_vcom1[] = {
    0x00, 0x10, 0x10, 0x01, 0x08, 0x01,
    0x00, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x00, 0x08, 0x01, 0x08, 0x01, 0x06,
    0x00, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x06,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x01,
    0x00, 0x04, 0x05, 0x08, 0x08, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
static unsigned char lut_ww1[] = {
    0x91, 0x10, 0x10, 0x01, 0x08, 0x01,
    0x04, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x84, 0x08, 0x01, 0x08, 0x01, 0x06,
    0x80, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x06,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x01,
    0x08, 0x04, 0x05, 0x08, 0x08, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
static unsigned char lut_bw1[] = {
    0xA8, 0x10, 0x10, 0x01, 0x08, 0x01,
    0x84, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x84, 0x08, 0x01, 0x08, 0x01, 0x06,
    0x86, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x8C, 0x05, 0x01, 0x1E, 0x0F, 0x06,
    0x8C, 0x05, 0x01, 0x1E, 0x0F, 0x01,
    0xF0, 0x04, 0x05, 0x08, 0x08, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
static unsigned char lut_wb1[] = {
    0x91, 0x10, 0x10, 0x01, 0x08, 0x01,
    0x04, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x84, 0x08, 0x01, 0x08, 0x01, 0x06,
    0x80, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x06,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x01,
    0x08, 0x04, 0x05, 0x08, 0x08, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
static unsigned char lut_bb1[] = {
    0x92, 0x10, 0x10, 0x01, 0x08, 0x01,
    0x80, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x84, 0x08, 0x01, 0x08, 0x01, 0x06,
    0x04, 0x06, 0x01, 0x06, 0x01, 0x05,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x06,
    0x00, 0x05, 0x01, 0x1E, 0x0F, 0x01,
    0x01, 0x04, 0x05, 0x08, 0x08, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

static void EPD_SetLut(void)
{
    UWORD count;
    EPD_M1S1M2S2_SendCommand(0x20);
    for(count = 0; count < 60; count++)
        EPD_M1S1M2S2_SendData(lut_vcom1[count]);
    EPD_M1S1M2S2_SendCommand(0x21);
    for(count = 0; count < 60; count++)
        EPD_M1S1M2S2_SendData(lut_ww1[count]);
    EPD_M1S1M2S2_SendCommand(0x22);
    for(count = 0; count < 60; count++)
        EPD_M1S1M2S2_SendData(lut_bw1[count]);
    EPD_M1S1M2S2_SendCommand(0x23);
    for(count = 0; count < 60; count++)
        EPD_M1S1M2S2_SendData(lut_wb1[count]);
    EPD_M1S1M2S2_SendCommand(0x24);
    for(count = 0; count < 60; count++)
        EPD_M1S1M2S2_SendData(lut_bb1[count]);
    EPD_M1S1M2S2_SendCommand(0x25);
    for(count = 0; count < 60; count++)
        EPD_M1S1M2S2_SendData(lut_ww1[count]);
}
