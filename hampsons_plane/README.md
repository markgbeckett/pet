# Hampson's Plane Tile-flipping Puzzle Game

This is a port of a tile-flipping game, called Hampson's Plane, to the Commodore PET. It is written for the BASIC 4.0 ROM and runs in 40-column mode.

The idea is to clear a randomly generated grid of tiles by 'flipping' squares. However, it is not quite that simple as when you flip a square, you also flip its eight neighbours. A timer tracks how quickly you can solve the puzzle, plus there are several difficulty levels to add to the challenge.

The original version of Hampson's Plane was written my Mike Hampson in 1981 and published in [SYNC magazine](https://spectrumcomputing.co.uk/page.php?issue_id=6188&page=38) as a type-in BASIC program for the ZX80. Several further versions were produced in subsequent years, including a FORTH version, written by Mike to demonstrate the capabilities of his [Spectrum FORTH compiler](https://www.spectrumcomputing.co.uk/entry/8742/ZX-Spectrum/Spectrum_FORTH) (published by CP Software in 1993).

It is the FORTH version that I encountered first and I ported that to work on the Minstrel 4th/ Jupiter Ace (see my [GitHub page](https://github.com/markgbeckett/jupiter_ace/tree/master/hampsons_plane)). I subsequently ported it to Z80 machine code to help me learn how to write flicker-free games for the ZX80 (again, see [my GitHub page](https://github.com/markgbeckett/jupiter_ace/tree/master/hampsons_plane)). Although, at that time, I was not aware of the game's origins on the ZX80. For the ZX80 port, I added in a clock to give the game a sense of urgency.

Finally, I have ported the game to the Commodore PET, as at attempt to learn how to program the computer and the 6502 processor.

## Running Hampson's Plane

To run the program, copy the [PRG](hampson.prg) file to a suitable media (e.g., an SD card for the [SD2PET adaptor](https://www.tfw8b.com/product/sd2pet-commodore-pet/) and load and run as for a BASIC program. E.g.,

```
load "hampson.prg",8
run
```

The program file includes the main (machine-code) program immediately after the program. If you try to edit/ list the BASIC program, you will probably crash the computer. If you're looking for the source code read on.

## Source Code

I have provided the [source code](hampson.asm) for my port of the game, so you can study or improve on what I have done. The source code can be built with the [ACME compiler](https://github.com/meonwax/acme) and is configured to produce a PRG file as output:

```
acme hampson.asm
```

Enjoy!
