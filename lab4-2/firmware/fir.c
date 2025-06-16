#include "fir.h"

int inputbuffer[N];
int y_hw;

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir(void)
{
	//initial your fir
	for (int i = 0; i < N; i++) inputbuffer[i] = 0;
	return;
}

void __attribute__ ( ( section ( ".mprjram" ) ) ) fir(void)
{

	reg_fir_len   = 64;
	reg_fir_ntaps = 11;

	for (i = 0; i < N; i++) {
    	*(&reg_fir_coeff0 + i) = taps[i];
    }

	reg_mprj_datal = 0xAB420000;
	
	reg_fir_control = FIR_START_BIT;

	reg_mprj_datal = 0x00A50000;

	reg_fir_x = 0;
	for (i = 1; i < DATA_LENGTH; i++) {
		reg_fir_x = i;
		y_hw = reg_fir_y;
	}
	y_hw = reg_fir_y;

	while ((reg_fir_control & FIR_DONE_BIT) == 0) { }
	reg_mprj_datal = 0x005A0000;

	reg_fir_control = FIR_START_BIT;


	reg_mprj_datal = 0x00A50000;

	for (i = 0; i < DATA_LENGTH; i++) {
    	reg_fir_x = i + 3;
    	y_hw = reg_fir_y;
	}
	while ((reg_fir_control & FIR_DONE_BIT) == 0) { }
	reg_mprj_datal = 0x005A0000;

	reg_fir_control = FIR_START_BIT;


	reg_mprj_datal = 0x00A50000;
	for (i = 0; i < DATA_LENGTH; i++) {
    	reg_fir_x = i + 5;
		y_hw = reg_fir_y;
	}
	while ((reg_fir_control & FIR_DONE_BIT) == 0) { }
	reg_mprj_datal = 0x005A0000;
}