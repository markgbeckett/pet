!to "scroll.prg",cbm
;; BASIC loader
;; 6502 SYS (1037)
	*=$0401
	!word end_of_stub
	!word 6502
	!byte $9e
	!text "1037"
	!byte 0
end_of_stub
	!word 0

	SCREEN=$8000
	SCREEN_END=$8400	; Check
	SCREEN_24=$83C0

	PDEST=$52

	lda #<SCREEN
	sta PDEST
	lda #>SCREEN
	sta PDEST+1

LOOP:	ldy #40
	lda (PDEST),y
	ldy #0
	sta (PDEST),y

	inc PDEST

	bne LOOP

	inc PDEST+1
	lda PDEST+1
	cmp #>SCREEN_END
	bne LOOP

	lda #20
	ldx #40

LOOP2:	sta SCREEN_24,x
	dex
	bne LOOP2

	rts
	
