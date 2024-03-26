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
	PROM=$50

START:	lda #$00
	sta PROM
	lda #$C0
	sta PROM+1

MAIN:	jsr SCROLL
	jmp MAIN

	
SCROLL:	lda #<SCREEN
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

	;; Print final line
	ldy #40			; Line length

LOOP2:
	;; Compute character to display (205 or 206)
	ldx #$4D
	lda (PROM),y
	dec PROM
	;; bne +
	;; dec PROM


+	lsr

	bcc SKIP		; 205
	inx			; 206
	
SKIP:	txa			; Put in A

sta SCREEN_24,y
	dey
	bne LOOP2

	rts
