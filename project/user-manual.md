# Microwave Emulator User Manual

## Modes
 1. **Entry**: Default mode that the microwave starts in. Cooking time can be entered and menus can be accessed to configure the microwave
 2. **Power Entry**: Microwave is waiting for input specifying power level
 3. **Running**: Microwave is active and is cooking food
 4. **Paused**: Microwave is inactive but part-way through cooking the food
 5. **Finished**: Cooking has been completed and the food should be removed

## Control Panel Summary
<table>
    <tr>
        <th>Component</th>
        <th>Symbol on Board</th>
        <th>Operation</th>
    </tr>
    <tr>
        <th rowspan="2">Push Buttons</th>
        <td>PB1</td>
        <td>
            Open door<br />
            <strong>In "Running"</strong>: Also changes mode to "Paused"
        </td>
    </tr>
    <tr>
        <td>PB0</td>
        <td>Close door</td>
    </tr>
    <tr>
        <th rowspan="6">Keypad</th>
        <td>0 - 9</td>
        <td>
            <strong>In "Entry"</strong>: Set cooking time. See "Cooking Time" section for more information<br />
            <strong>In "Power Entry"</strong>: Set power level and return to "Entry" mode
        </td>
    </tr>
    <tr>
        <td>A</td>
        <td><strong>In "Entry"</strong>: Enter "Power Entry" mode</td>
    </tr>
    <tr>
        <td>C</td>
        <td><strong>In "Running"</strong>: Add 30 seconds to cooking time</td>
    </tr>
    <tr>
        <td>D</td>
        <td><strong>In "Running"</strong>: Subtract 30 seconds to cooking time</td>
    </tr>
    <tr>
        <td>*</td>
        <td>
            <strong>In "Entry"</strong>: Enter "Running" mode and start the microwave. Timer defaults to 1:00 if unset<br />
            <strong>In "Running"</strong>: Add 1 minute to the cooking time
        </td>
    </tr>
    <tr>
        <td>#</td>
        <td>
            <strong>In "Entry"</strong>: Clear any entered time<br />
            <strong>In "Power Entry"</strong>: Return to "Entry" mode<br />
            <strong>In "Running"</strong>: Enter "Paused" mode and pause the microwave<br />
            <strong>In "Paused" or "Finished"</strong>: Clear any current time and return to "Entry" mode
        </td>
    </tr>
    <tr>
        <th colspan="2">LCD</th>
        <td>Shows the current microwave status. See "LCD" section for more information</td>
    </tr>
    <tr>
        <th>Bottom 8 LEDs</th>
        <td rowspan="2">LED BAR</td>
        <td>Shows current power level. See "LED Bar" section for more information</td>
    </tr>
    <tr>
        <th>Topmost LED</th>
        <td>Shows the door state. It will be lit if and only if the door is open</td>
    </tr>
</table>

## Setting up the emulator
The potentiometer should be set to a third of its maximum resistance.

The following pins should be wired together. Ranges are specified as A → B.<br />
Labelled MCU pins are only provided as a convenience, and may not match the labels actual labels on your board.

<table>
    <tr><th>Component Pin</th><th>Labelled MCU Pin</th><th>Actual MCU Pin</th></tr>
    <tr><th colspan="3">Motor and Optical Detector</th></tr>
    <tr><td>OpE</td><td>+5V</td><td>+5V</td></tr>
    <tr><td>OpO</td><td>TDX2</td><td>PD2</td></tr>
    <tr><td>JP91-Right</td><td>PE2</td><td>PE4</td></tr>
    <tr><td>Mot</td><td>POT</td><td>N/A (Component Pin)</td></tr>
    <tr><th colspan="3">Speaker</th></tr>
    <tr><td>AIn</td><td>PH8</td><td>PH5</td></tr>
    <tr><th colspan="3">LCD</th></tr>
    <tr><td>D0 → D7</td><td>PK8 → PK15</td><td>PK0 → PK7</td></tr>
    <tr><td>BE</td><td>PA4</td><td>PA4</td></tr>
    <tr><td>RW</td><td>PA5</td><td>PA5</td></tr>
    <tr><td>E</td><td>PA6</td><td>PA6</td></tr>
    <tr><td>RS</td><td>PA7</td><td>PA7</td></tr>
    <tr><td>BL</td><td>PH9</td><td>PH6</td></tr>
    <tr><th colspan="3">Buttons</th></tr>
    <tr><td>PB0</td><td>RDX4</td><td>PD0</td></tr>
    <tr><td>PB1</td><td>RDX3</td><td>PD1</td></tr>
    <tr><th colspan="3">LED Bar</th></tr>
    <tr><td>LED0</td><td>PG1</td><td>PG2</td></tr>
    <tr><td>LED2 → LED9</td><td>PC0 → PC7</td><td>PC7 → PC0</td></tr>
    <tr><th colspan="3">Keypad</th></tr>
    <tr><td>C3 → C0</td><td>PL0 → PL3</td><td>PL7 → PL4</td></tr>
    <tr><td>R3 → R0</td><td>PL4 → PL7</td><td>PL3 → PL0</td></tr>
    <tr><th colspan="3">Keypad: Connect the following two MCU pin ranges together</th></tr>
    <tr><td>N/A</td><td>PL4 → PL7</td><td>PL3 → PL0</td></tr>
    <tr><td>N/A</td><td>PB0 → PB3</td><td>PB3 → PB0</td></tr>
</table>

## Power Selection
 1. Press key 'A' during "Entry" mode to enter "Power Entry" mode
 2. The LCD will display the text "Set Power 1/2/3"
 3. Press one of the following keys:
    - '1': 100% power
    - '2': 50% power
    - '3': 25% power
    - '#': Exit "Power Entry" mode without any changes
 4. Upon any of the above keys being pressed, the microwave will automatically return to "Entry" mode
 5. The current power level will be indicated by percentage of the bottom 8 LEDs lit on the LED bar

## Cooking time
 1. During "Entry" mode, use the number keys to set the cooking time in the format 'mm:ss'. Only four digits are accepted at most
    - For example, for a cooking time of 2 minutes 30 seconds, press '2', '3' and '0' in that order
 2. If a number is held down, only one digit will be entered.
 3. Press '*' to start the microwave.

Notes:
 - '#' can be pressed to clear the currently entered time before the microwave has started
 - In "running" mode
    - Pressing 'C' will add 30 seconds to the cooking time
    - Pressing 'D' will subtract 30 seconds from the cooking time
    - Pressing '*' will add 1 minute to the cooking time

## LCD
<style>
    .lcd {
        display: inline-block;
        background-color: yellowgreen;
        border: 1px solid black;
        font-family: monospace;
        white-space: pre;
        letter-spacing: 1em;
    }
</style>
The following apply to all modes:
 - **Top-right corner**: Current position of microwave turntable '-', '/', '|', or '\'
 - **Bottom-right corner**: Opened ('O') or closed ('C') door status. By default, the door is closed

### Default display in "Entry" mode
<div class="lcd">  :            -<br / >               C</div>

When the display looks like this, the microwave is in "Entry" mode and cooking time can be entered.

### Default display in "Power Entry" mode
<div class="lcd">  :            -<br / >Set Power 1/2/3C</div>

When the display looks like this, the microwave is in "Power Entry" mode and the power level can be entered.

### Example display in "Running" or "Paused" mode
<div class="lcd"> 2:59          \<br / >               C</div>

When the display looks like this, the timer is counting down and the turntable is spinning, the microwave is in "Running" mode.<br />
Otherwise, the microwave is likely in "Paused" mode.

### Default display in "Finished" mode
<div class="lcd">Done           -<br / >Remove food    C</div>

When the display looks like this, the microwave is in "Finished" mode and the food should now be removed.

## LED Bar
<style>
    .led-bar td, .led-bar th {
        border: 1px solid black;
        width: 5em;
        height: 2em;
    }
    .led-bar th {
        background-color: greenyellow;
    }
</style>
The topmost LED is lit when the door is open. The bottom 8 LEDs indicate the current power level.

<table>
    <tr>
        <th>Door is Open</th>
        <th>100% Power</th>
        <th>50% Power</th>
        <th>25% Power</th>
    </tr>
    <tr>
        <td>
            <table class="led-bar">
                <tr><th style="background-color: red"></th></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
            </table>
        </td>
        <td>
            <table class="led-bar">
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
            </table>
        </td>
        <td>
            <table class="led-bar">
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
            </table>
        </td>
        <td>
            <table class="led-bar">
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><td></td></tr>
                <tr><th></th></tr>
                <tr><th></th></tr>
            </table>
        </td>
    </tr>
</table>
