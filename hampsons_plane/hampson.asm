!to "hampson.prg",cbm
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

	DISPLAY=$8000		; Start of screen memory
	CLR_HOME=$93		; Clear-home character
	
	CHROUT=$FFD2		; New ROM Clear Screen routine
	
	SEED=$50		; Seed for random-number generator
	LOCN=$52		; Zero-page store for address
	
	;; Fill in grid
	ROW=$54
	COL=$55

	;; Count of number of stars on game board
	STAR_CNT=$56

	;; Temporary counter
	COUNT=$58

	;; Temp values
	TMP1=$5B
	STRING_PTR=$5D
	
HAMPSON:
	;; Seed random-number generator
	lda $008F		; Retrieve low byte of 
				; seed from jiffy clock
	sta SEED
	lda #01			; Set high byte to non-zero
				; to avoid risk of zero starting seed
	sta SEED+1

	;; Zero star counter
	lda #00
	sta STAR_CNT
	sta STAR_CNT+1
	
	;; Set flip counter
	lda #00
	sta COUNT
	lda #04
	sta COUNT+1

	;; Print game board
	jsr SETUP_BD
	
	;; Done
	rts

	;; Convert game-board coordinates to a display address (for
	;; top-left corner of 3x3 cell)
	;;
	;; On entry:
	;;   LOCN    - game-board row coordinate
	;;   LOCN+1  - game-board column coordinate
	;;
	;; On exit:
	;;   LOCN    - address computed (word)
	;;   A, X, Y - corrupted
BC2A:	; Convert screen coordinate to game board coordinate
	clc
	lda LOCN
	adc #03
	sta LOCN
	lda LOCN+1
	adc #06
	sta LOCN+1
	
	;; Convert screen coordinates to a display address
	;;
	;; On entry:
	;;   LOCN    - row number (0...24)
	;;   LOCN+1  - column number (0...39)
	;;
	;; On exit:
	;;   LOCN    - address computed (word)
	;;   A, X, Y - corrupted
C2A:
	ldy LOCN		; Retrieve row offset
	ldx LOCN+1		; Retrieve col offset

	lda ROWSTART_HI,y	; Retrieve high byte of row start
	sta LOCN+1 		; Store

	txa			; Move column offset into A
	clc			; Clear carry
	adc ROWSTART_LO,y	; Add to low byte of row start
	sta LOCN		; Store

	lda LOCN+1		; Deal with any carry to high byte
	adc #00
	sta LOCN+1

	rts

	;; Look-up table of screen address of first character
	;; in each of the 25 screen rows (low byte first)
ROWSTART_LO:
	!byte $00, $28, $50, $78, $A0, $C8, $F0, $18
	!byte $40, $68, $90, $B8, $E0, $08, $30, $58
	!byte $80, $A8, $D0, $F8, $20, $48, $70, $98
	!byte $C0
	
ROWSTART_HI:
	!byte $80, $80, $80, $80, $80, $80, $80, $81
	!byte $81, $81, $81, $81, $81, $82, $82, $82
	!byte $82, $82, $82, $82, $83, $83, $83, $83
	!byte $83	

	;; Flip 3x3 block of tiles
	;;
	;; On entry:
	;;   LOCN    - game-board row coordinate
	;;   LOCN+1  - game-board column coordinate
	;;   STAR_CNT - number of visible stars
	;; 
	;; On exit:
	;;   STAR_CNT - updated number of visible stars
	;;   LOCN(2) - corrupted
	;;   A, X, Y - corrupted
FLIP9:	jsr BC2A		; Convert coord at LOCN to address

	ldx #03			; Three rows to flip
FL_ROW:	ldy #03			; Three columns to flip

FL_CHR:	lda (LOCN),y		; Retrieve current character
	eor #$0A		; Flip it (char 42 = */ 32 = SPACE)
	sta (LOCN),y		; Store it
	
	;; Update star count
FL_CONT:
	cmp #42			; Check if star
	bne FL_CONT_2		; Skip forward if not
	
	clc			; Otherwise, add 2
	lda #2
	adc STAR_CNT
	sta STAR_CNT
	bcc FL_CONT_2		; Check for and deal with carry
	inc STAR_CNT+1
	
FL_CONT_2:	
	lda STAR_CNT		; Decrement to correct
	bne FL_DEC
	dec STAR_CNT+1		
FL_DEC:	dec STAR_CNT
	
	;; Check if more columns to flip
	dey
	bne FL_CHR

	;; Advance to start of next row (40 characters on)
	clc
	lda #40
	adc LOCN
	sta LOCN
	bcc FL_NC		; Deal with carry
	inc LOCN+1

	;; Check if is next row
FL_NC:	dex
	bne FL_ROW

	;; Done
	rts

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

	;; Divide by 10
	;; See http://6502org.wikidot.com/software-math-intdiv for details
DIV10:	lda #0
	ldx #8
	asl TMP1
D1:	rol
	cmp #$0A
	bcc D2
	sbc #$0A
D2:	rol TMP1
	dex
	bne D1

	rts

	;; Print string to screen
	;;
	;; On entry:
	;;   LOCN, LOCN+1 - location to print to
	;;   STRING_PTR - address of string (terminated with $FF)
	;;
	;; On exit:
	;; 
PRINT_STR:
	;; Retrieve coordinates and work out address
	jsr C2A 		
	
	ldy #00

	;; Print character and advance
PS_LOOP:
	lda (STRING_PTR),y
	cmp #$FF
	beq PS_DONE
	
	sta (LOCN),y
	iny
	bne PS_LOOP

PS_DONE:
	rts

	;; Print number to screen
	;;
	;; On entry:
	;;   LOCN, LOCN+1 - location to print to
	;;   A - number to print (binary coded decimal)
	;;
	;; On exit:
	;; 
PRINT_NUM:
	pha			; Save A for later
	
	jsr C2A			; Convert screen coords into address

	pla			; Retrieve and save number
	pha

	;; Isolate high digit
	and #$F0
	lsr
	lsr
	lsr
	lsr

	;; Translate to screen code
PN_LOOP:
	adc #48			; Carry will be cleared by previous shift
	ldy #00
	sta (LOCN),y

	;; Retrieve low byte
	pla

	and #$0F
	adc #48
	iny
	sta (LOCN),y
	
	rts

	;; Clear screen and print game board
	;;
	;; On entry:
	;;   COUNT - number of random flips to make
	;;   STAR_CNT - zeroed
	;; 
	;; On exit:
	;;   STAR_CNT - number of visible stars in puzzle
SETUP_BD:
	lda #CLR_HOME		; Clear screen
	jsr CHROUT	

	;; Print top border
	lda #02
	sta LOCN
	lda #05
	sta LOCN+1
	
	lda #<ROW_STR_1
	sta STRING_PTR
	lda #>ROW_STR_1
	sta STRING_PTR+1

	jsr PRINT_STR
	
	;; Print bottom border
	lda #21
	sta LOCN
	lda #05
	sta LOCN+1
	
	lda #<ROW_STR_1
	sta STRING_PTR
	lda #>ROW_STR_1
	sta STRING_PTR+1

	jsr PRINT_STR

	;; Print game-board corners
	lda #$A0
	sta DISPLAY+3*40+5
	sta DISPLAY+3*40+6
	sta DISPLAY+20*40+5
	sta DISPLAY+20*40+6
	sta DISPLAY+3*40+35
	sta DISPLAY+3*40+36
	sta DISPLAY+20*40+35
	sta DISPLAY+20*40+36
		
	;; Print game-board sides
	lda #01
	sta TMP1
	lda #16
	sta TMP1+1
	
SB_LOOP:
	;; Start with left column
	sec
	lda #20
	sbc TMP1+1
	sta LOCN
	lda #05
	sta LOCN+1

	lda TMP1
	jsr PRINT_NUM

	;; Then right column
	sec
	lda #20
	sbc TMP1+1
	sta LOCN
	lda #35
	sta LOCN+1

	lda TMP1
	jsr PRINT_NUM

	;; increment coordinate label (binary coded decimal)
	sed
	lda TMP1
	clc
	adc #01
	sta TMP1
	cld
	
	dec TMP1+1
	bne SB_LOOP
	
	;; Randomly create starting board
	jsr RAND_BOARD

	rts

ROW_STR_1:
	!byte $A0, $A0, $A0
	!byte $01, $02, $03, $04, $05, $06, $07, $08
	!byte $09, $0A, $0B, $0C, $0D, $0E, $0F, $10
	!byte $11, $12, $13, $14, $15, $16, $17, $18
	!byte $19, $1A
	!byte $A0, $A0, $A0, $FF

ROW_STR_2:
	!byte $A0, $A0, $FF
	
	;; Initialise game by completing a number of flip operatons
	;; of random cells, based on counter stored in COUNT (word)
	;;
	;; On entry:
	;;   COUNT - number of flips to perform
	;;
	;; On exit:
	;;   
RAND_BOARD:
	jsr RAND16

	lda SEED
	and #$0F
	sta LOCN

	lda SEED+1
	sta TMP1
	jsr DIV10
	lda TMP1
	sta LOCN+1

	jsr FLIP9

	;; Decrement 16-bit counter
	lda COUNT
	bne SB_DEC
	dec COUNT+1
SB_DEC:	dec COUNT
	
	;; Check if counter is zero
	lda COUNT
	ora COUNT+1
	
	bne RAND_BOARD

	rts
