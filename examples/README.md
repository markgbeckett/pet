# Commodore PET Pattern Generator

This is a machine-code version of the classic Commodore BASIC one-liner:

```
10 PRINT CHR$(205.5 + RND(1)); : GOTO 10
```

-- which fills the screen with a pleasing, maze-like pattern.

I wrote the machine code version to get some experience with 6502 machine code. It is a little longer than the BASIC original, but also runs much more quickly.

The source file can be assembled with the [Acme assembler](https://sourceforge.net/projects/acme-crossass/), using:

```
acme scroll.asm
```

-- and then either loaded int a PET emulator such as [Vice](https://vice-emu.sourceforge.io/) or into a reall PET with an [SD2PET interface](https://www.tfw8b.com/product/sd2pet-commodore-pet/).

The program runs perpetually. To stop, you need to press Reset or power-cycle the machine.
