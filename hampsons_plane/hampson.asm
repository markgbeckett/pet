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
	
	GETIN=$FFE4		; Read keyboard
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
	lda #00
	sta COUNT+1

	;; Print game board
	jsr SETUP_BD
	
	;; Query for game level
	jsr GET_LEVEL
	
	;; Randomly create starting board
	jsr RAND_BOARD

	;; Game loop
GLOOP:	jsr GET_COORD

	;; Flip tiles
	jsr FLIP9

	;; Check if done
	lda STAR_CNT
	ora STAR_CNT+1
	bne GLOOP
	
	;; Done
	rts

	;; Convert game-board coordinates to a display address (for
	;; top-left corner of 3x3 cell)
	;;
	;; On entry:
	;;   ROW    - game-board row coordinate
	;;   COL    - game-board column coordinate
	;;
	;; On exit:
	;;   LOCN    - address computed (word)
	;;   A, X, Y - corrupted
BC2A:	; Convert screen coordinate to game board coordinate
	clc
	lda ROW
	adc #03
	sta ROW
	lda COL
	adc #06
	sta COL
	
	;; Convert screen coordinates to a display address
	;;
	;; On entry:
	;;   ROW    - row number (0...24)
	;;   COL    - column number (0...39)
	;;
	;; On exit:
	;;   LOCN    - address computed (word)
	;;   A, X, Y - corrupted
C2A:
	ldy ROW			; Retrieve row offset
	ldx COL			; Retrieve col offset

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
	;;   ROW     - game-board row coordinate
	;;   COL     - game-board column coordinate
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
	sta ROW
	lda #05
	sta COL
	
	lda #<ROW_STR_1
	sta STRING_PTR
	lda #>ROW_STR_1
	sta STRING_PTR+1

	jsr PRINT_STR
	
	;; Print bottom border
	lda #21
	sta ROW
	lda #05
	sta COL
	
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
	sta ROW
	lda #05
	sta COL

	lda TMP1
	jsr PRINT_NUM

	;; Then right column
	sec
	lda #20
	sbc TMP1+1
	sta ROW
	lda #35
	sta COL

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
	
CHECK_NO_KEY:
	jsr GETIN
	bne CHECK_NO_KEY

	rts

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
	sta ROW

	lda SEED+1
	sta TMP1
	jsr DIV10
	lda TMP1
	sta COL

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

GET_LEVEL:
	;; Print message
	lda #23
	sta ROW
	lda #06
	sta COL
	
	lda #<GL_STR
	sta STRING_PTR
	lda #>GL_STR
	sta STRING_PTR+1

	jsr PRINT_STR

	;; Retrieve keypress
GL_READ:
	jsr GETIN
	beq GL_READ

	;; On exit A contains 30, ..., 39
GL_PROCESS:
	cmp #$30		; Check range
	bcc GL_READ
	cmp #$40
	bcs GL_READ

	;; Convert to level
	sec
	sbc #$2F
	sta COUNT

	;; Print level
	tax
	lda #23
	sta ROW
	lda #31
	sta COL

	txa
	sec
	sbc #01

	jsr PRINT_NUM
	
	;; Done
	rts

	;; Prompt user for coordinate of tile to flip
	;; Store coordinate in ROW, COL
GET_COORD:
	;; Print request to enter coordinate at (23,06)
	lda #23
	sta ROW
	lda #06
	sta COL
	
	lda #<GL_STR_2
	sta STRING_PTR
	lda #>GL_STR_2
	sta STRING_PTR+1

	jsr PRINT_STR

	;; Retrieve column value (A,..., Z)
GC_READ:
	jsr GETIN
	beq GC_READ		; Repeat, if no key pressed

	;; On exit A should contain 65 ('A'), ..., 90 ('Z')
	cmp #$41		; Check range
	bcc GC_READ
	cmp #$5B
	bcs GC_READ
	
	;;  Normalise to 1...26 for printing
	sec
	sbc #$40
	sta $83B5		; Print it
	
	;;  Normalise to 0...25 for game
	sec
	sbc #01
	
	sta COL
	
	;; Set row value to zero
	lda #00
	sta ROW

	jsr CHECK_NO_KEY
	
	;; Retrieve high row value
GC_READ_2:
	jsr GETIN
	beq GC_READ_2		; Repeat, if no key pressed

	;; On exit A should contain 30 or 31
	cmp #$30		; Check for '0'
	beq GC_PR_0		; Move on if so,
	cmp #$31		; Check for '1'
	bne GC_READ_2		; Repeat if not

	sta $83B6		; Print it
	
	;; '1' pressed, so set row base to 10
	lda #$0A
	sta ROW

	jmp GC_ROW_LOW		; Skip next instruction (could be BNE)
	
GC_PR_0:
	sta $83B6		; Print digit
	
GC_ROW_LOW:	
	jsr CHECK_NO_KEY
	
	;; Retrieve low row value
GC_READ_3:
	jsr GETIN
	beq GC_READ_3		; Repeat, if no key pressed

	;; On exit A contains 30, ..., 39
	cmp #$30		; Check range
	bcc GC_READ_3
	cmp #$40
	bcs GC_READ_3

	sta $83B7		; Print it
	
	;; Translate into digit (normalise on zero)
	sec
	sbc #$31

	;; And update row value
	clc
	adc ROW
	sta ROW

	rts			; Done
	
	
GL_STR:	!byte 03, 08, 15, 15, 19, 05, 32
	!byte 19, 11, 09, 12, 12, 32
	!byte 12, 05, 22, 05, 12, 32
	!pet "(0-9)"
	!byte $FF

	;; ENTER MOVE (COL FIRST)
GL_STR_2:
	!byte 05, 14, 20, 05, 18, 32
	!byte 13, 15, 22, 05, 32
	!pet "("
	!byte 03, 15, 12, 32
	!byte 06, 09, 18, 19, 20
	!pet ")"
	!byte 32, 32, 32, 32, 32, 32, 32, $FF	
