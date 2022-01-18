A Software Package: Interactive Musculoskeletal Model Programmed in Simulink

Written by: Julia Manczurowsky, Mansi Badadhe, and Christopher J. Hasson
Date: 8/5/21

The files contained in this package:

1. InteractiveArmModel_R2021a_v1.slx [Simulink Model]
2. InteractiveDisplay.m [Helper Matlab Script]
3. arduinoSerialEMG.ino [Arduino Code for reading EMG]

Program Notes:

This program is an interactive musculoskeletal model that can be controlled by myoelectric activity (or keyboard or mouse). Background and details about the model can be found in Manczurowsky et al. (2022): 

Manczurowsky JR, Badadhe M, and Hasson CJ (2022). Visual Programming for Accessible Interactive Musculoskeletal Models. BMC Research Notes (in revision).

The program should run "out-of-the-box" using Matlab/Simulink R2021a or higher using keyboard or mouse control. Just click "Run" on the "Simulation" tab at the top. You may need to adjust the solver integration step size, depending on your computer. A "slow" computer might need a larger step size. Go to the "Modeling" tab, select "Model Settings", then "Solver", and then change the "Fixed-step size" setting in the text box.

Using EMG takes more setup. The program is designed to work with EMG collected by an Arduino microprocessor (The Simulink support package for Arduino is only needed if you are actually trying to run the program on the Arduino itself, which won't work because of the use of a custom S-Function). To use an Arduino to collect EMG, you need to install Arduino drivers, and then just select the appropriate COM port in the "Specify Model Parameters" section of the Simulink program. The actual reading of the seral port takes place in the "InteractiveDisplay.m" function using the "serialport" command. To setup the Arduino, use the Arduino script "arduinoSerialEMG.ino". This can be downloaded to the Arduino using the IDE, which can be found at: 

https://www.arduino.cc/en/Main/Software_

The Arduino script sets a 19200 baud rate and instructs the Arduino to read from analog input channels 0 and 1. It then writes the values (in bits) to the serial port. The first channel is preceded by a "A" and the second by a "B" and is terminated by an "X". The Matlab script ("InteractiveDisplay.m") decodes this serial string to get the correct channel values for the virtual arm. More details on the EMG setup can be found in Manczurowsky et al. (2022).

Note that this is "Version 1" and although care was taken for debugging, there may still very well be bugs. We found that in some cases, visually programming functionality previously obtained using a text-based programming language can present difficulties.


