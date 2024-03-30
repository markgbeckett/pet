	;; Scrolling maze demo
	
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

	SCREEN=$8000		; Start of screen
	SCREEN_END=$8400	; End of screen
	SCREEN_24=$83C0		; Line 24 of screen

	PROM=$50		; Store for ROM address (used to create
				; randomised pattern)
	PDEST=$52		; Store for current destination in
				; screen
	SEED=$54
	
START:	lda #$00		; Initialise ROM pointer (start of 
	sta PROM		; BASIC ROM)
	lda #$C0
	sta PROM+1

	;; Seed random-number generator
	lda #1
	sta SEED
	lda #0
	sta SEED+1


	;; Infinite loop to scroll screen and generate new final row
MAIN:	jsr SCROLL
	jmp MAIN

	;; Scroll screen up by one row (based on algorithm by Rodnay
	;; Zaks, "Programming the 6502")
SCROLL:	lda #<SCREEN
	sta PDEST
	lda #>SCREEN
	sta PDEST+1

LOOP:	ldy #40			; 40 characters per row, so indexes
	lda (PDEST),y		; corresonding character in next row
	ldy #0
	sta (PDEST),y

	inc PDEST		; Advance to next character

	bne LOOP		; If not wrapped around loop

	inc PDEST+1		; Increase MSB
	lda PDEST+1
	cmp #>SCREEN_END	; End of screen?
	bne LOOP		; Loop if not

	;; Print final line
	ldy #40			; Line length

LOOP2:
	;; Compute character to display ($4D/ $4E)
	ldx #$4D
	;; lda (PROM),y		; Retrieve value from ROM to create
	;; dec PROM		; random 1 or 0
	jsr RAND16
	
	lsr			; Check bit 0

	bcc SKIP		; Character is $4D

	inx			; Character is $4E
	
SKIP:	txa			; Put in A

	sta SCREEN_24,y		; Write to screen
	dey			; Next (actually previous) character
	bne LOOP2		; Repeat if not done

	rts			; Done

	;; Pseudo-random-number generator. You can get 8-bit
	;; random numbers in A or 16-bit numbers from the zero
	;; page addresses. Leaves X/Y unchanged.
	;;
	;; See https://codebase64.org/doku.php?id=base:16bit_xorshift_random_generator
	
RAND16:	lda SEED+1
        lsr
        lda SEED
        ror
        eor SEED+1
        sta SEED+1	; high part of x ^= x << 7 done
        ror             ; A has now x >> 9 and high bit comes from low byte
        eor SEED
        sta SEED  	; x ^= x >> 9 and the low part of x ^= x << 7 done
        eor SEED+1 
        sta SEED+1 	; x ^= x << 8 done
	
        rts

