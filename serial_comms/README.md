# PET Serial Communications

## Introduction

Possibly the easiest way to get a terminal program working on your Commodore PET or Tynemouth MiniPET is to use a Tynemouth PET serial adaptor and the [PET TERM program](https://github.com/ChartreuseK/PETTERM).

Two versions of PET TERM are relevant for these instructions:

- `PETTERM40G.PRG` - Version wrapped with a BASIC loader for a 40-column, graphics keyboard version of the original program, which can send and receive characters via a terminal-like interface on the PET. To start, simply `RUN` the BASIC program. When using the terminal, press "CLR/HOME" to return to the menu. To exit, I think you need to Reset the computer.

- `PETTERM32K_40G.PRG` - Machine-code block loaded into upper memory, PET with 32 kilobytes of RAM and using a 40-column display. This version can also be used to load and save BASIC programs.

## Hardware setup

Simply connect the serial interface to the User Port on the back of your Mini PET (the FTDI connector should be facing upwards, when the card is connected). Then connect an FTDI cable (ground is on left, if you are facing the computer from the front) and connect the USB connector to your PC.

Set up your terminal program. By default, Baud rate is 1,200 bps, 8-bit data with no parity and one stop bit (this is summarised on-screen, when using PET TERM). You should also turn off flow control.

You should also set the terminal program to translate Carriage Return as Carriage Return and Line Feed, to ensure the cursor advances to the next line on the Mini PET end.

You can experiment with increased Baud rates, though the lack of flow control means you may see errors, if you set the rate to be too high. People have noted that 2400 Baud is a bit unreliable in newer versions of the software.


## Loading a BASIC program

Having set up the hardware, run the high-memory version of the program using:

``DLOAD "PETTERM3240",8``

--and run, using:

``SYS 20480``

From the main menu, you can configure the Baud rate, plus set your preferred character encoding.

Select option 7 to load a program. Then set up an XMODEM Send operation, selecting the PNG file that you wish to load. Once the transfer has been set up, press a key on the Mini PET to begin loading.

Once loaded, press 'CLR/HOME' to return to the main menu, then press 'X' and 'Return' to exit. You can then use/ work on your BASIC program.

Assuming the BASIC program is not too large, you should be able to restart the terminal program again -- for example, to save a version over the serial connection to your PC.
