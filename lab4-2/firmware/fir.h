#ifndef __FIR_H__
#define __FIR_H__


#define N 11
#define DATA_LENGTH 64

#define reg_fir_control (*(volatile uint32_t*)0x30000000)

#define FIR_START_BIT (1U << 0)
#define FIR_DONE_BIT  (1U << 1)
#define FIR_IDLE_BIT  (1U << 2)
#define FIR_XRDY_BIT  (1U << 4)
#define FIR_YRDY_BIT  (1U << 5)

#define reg_fir_len     (*(volatile uint32_t*)0x30000010)
#define reg_fir_ntaps   (*(volatile uint32_t*)0x30000014)

#define reg_fir_x       (*(volatile uint32_t*)0x30000040)
#define reg_fir_y       (*(volatile uint32_t*)0x30000044)

#define reg_fir_coeff0  (*(volatile uint32_t*)0x30000080)
#define reg_fir_coeff1  (*(volatile uint32_t*)0x30000084)
#define reg_fir_coeff2  (*(volatile uint32_t*)0x30000088)
#define reg_fir_coeff3  (*(volatile uint32_t*)0x3000008C)
#define reg_fir_coeff4  (*(volatile uint32_t*)0x30000090)
#define reg_fir_coeff5  (*(volatile uint32_t*)0x30000094)
#define reg_fir_coeff6  (*(volatile uint32_t*)0x30000098)
#define reg_fir_coeff7  (*(volatile uint32_t*)0x3000009C)
#define reg_fir_coeff8  (*(volatile uint32_t*)0x300000A0)
#define reg_fir_coeff9  (*(volatile uint32_t*)0x300000A4)
#define reg_fir_coeff10 (*(volatile uint32_t*)0x300000A8)

static const int taps[N] = {0,-8,-10,3,26,35,-18,25,-12,5,0};

void initfir(void);
void fir(void);

#endif
