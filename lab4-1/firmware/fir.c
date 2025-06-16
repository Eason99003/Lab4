#include "fir.h"

int inputbuffer[N];
int outputsignal[N];

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir(void)
{
	//initial your fir
	for (int i = 0; i < N; i++) inputbuffer[i] = 0;
	return;
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(void)
{
	int i, j, k;
	int acc = 0;
	
	initfir();
	//write down your fir
	for (i = 0; i < N; i++) {
        // shift buffer
        for (j = N - 1; j > 0; j--) inputbuffer[j] = inputbuffer[j - 1];
        inputbuffer[0] = inputsignal[i];

        acc = 0;
        for (k = 0; k < N; k++) acc += taps[k] * inputbuffer[k];
        outputsignal[i] = acc;
    }
    
	return outputsignal;
}
		
