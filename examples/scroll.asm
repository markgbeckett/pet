	;; Scrolling maze demo for Commodore PET (40-col mode)
	;;
	;; Machine-code implementation of the classic BASIC program:
	;;
	;; 10 PRINT CHR$(205.5 + RND(1)); : GOTO 10
	;;
	;; Written by George Beckett, 2024

	;; Header for ACME compiler to create PRG file that can be
	;; loaded directly into a PET or PET emulator.
!to "scroll.prg",cbm
	;; BASIC loader
	;; 6502 SYS (1037)
	*=$0401
	!word end_of_stub
	!word 100
	!byte $9e
	!text "1037"
	!byte 0
end_of_stub
	!word 0

	;; Screen memory locations
	SCREEN=$8000		; Start of screen
	SCREEN_END=$8400	; End of screen (actually $83E8, but
				; $8400 is easier to test for)
	SCREEN_24=$83C0		; Start of line 24 of screen
	ROW_LENGTH=$40		; Length of PET-screen row
	;; Useful Page 0 storage
	PDEST=$52		; Store for current destination in
				; screen
	SEED=$54		; Random-number seed
	
START:	;; Seed random-number generator (must be non-zero)
	lda #1
	sta SEED
	lda #0
	sta SEED+1

	;; Infinite loop to scroll screen and generate new final row
MAIN:	jsr SCROLL

	jmp MAIN		; Repeat

	
	;; Scroll screen up by one row
	;; 
	;; Timing: 14 + 4*255*19 + 3*30 + 29 = 19,513 cycles
SCROLL:	lda #<SCREEN		; (2)
	sta PDEST		; (3)
	lda #>SCREEN		; (2)
	sta PDEST+1		; (3)

	ldy #ROW_LENGTH		; (2) 40 characters per row, so index
				; provides offset to corresponding
				; character in next row
	ldx #0			; (2) Offset zero to destination

	;; Scroll screen up by one row (based on algorithm by Rodnay
	;; Zaks, "Programming the 6502")

	;; Timing - Inner loop (19) / Outer loop (30/ 29))
LOOP:
	; Copy character from row below to current row
	lda (PDEST),y		; (5) corresonding character in next row
	sta (PDEST,x)		; (6) 

	inc PDEST		; (5) Incremement LSB to advance to next
				; character

	bne LOOP		; (3/2) If not wrapped around loop

	;; Other increment MSB and check if end of screen
	inc PDEST+1		; (5) Increase MSB
	lda PDEST+1		; (2) and store

	cmp #>SCREEN_END	; (2) End of screen?
	bne LOOP		; (3/2) Loop if not

	;; Create new final line (based on random mox of character $4D
	;; and $4E). Note we start at right-hand end
	ldy #ROW_LENGTH		; Line length

LOOP2:
	;; Compute character to display ($4D/ $4E)
	ldx #$4D		; Character code
	
	jsr RAND16		; Generate random number
	
	lsr			; Use bit 0 as modifier for character code

	bcc SKIP		; Character is $4D

	inx			; Character is $4E
	
SKIP:	txa			; Move character into A (from X)

	sta SCREEN_24-1,y	; Write to screen
	dey			; Next (actually previous) character
	bne LOOP2		; Repeat if not done

	rts			; Done

	;; Pseudo-random-number generator. You can get 8-bit
	;; random numbers in A or 16-bit numbers from the zero
	;; page addresses. Leaves X/Y unchanged.
	;;
	;; (36 clock cycles)
	;; 
	;; See
	;; https://codebase64.org/doku.php?id=base:16bit_xorshift_random_generator
	
RAND16:	lda SEED+1		; (3)
        lsr			; (2)
        lda SEED		; (3)
        ror			; (2)
        eor SEED+1		; (3)
        sta SEED+1		; (3) high part of x ^= x << 7 done
        ror             	; (2) A has now x >> 9 and high bit
				; comes from low byte
        eor SEED		; (3)
        sta SEED  		; (3) x ^= x >> 9 and the low part of x
				; ^= x << 7 done
        eor SEED+1 		; (3)
        sta SEED+1 		; (3) x ^= x << 8 done
	
        rts			; (6)

END:
