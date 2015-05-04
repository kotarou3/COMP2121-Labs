#ifndef KEYPAD_H
#define KEYPAD_H

#ifndef ALL_ASSEMBLY

void onKeypadPress(void (*callback)(char));
void keypadSetup();

#endif

#endif
