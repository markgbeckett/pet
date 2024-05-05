	;; Hampson's Plane is a tile-flipping game, created by Mark
	;; Hampson as a BASIC type-in for the ZX80 in 1981 (SYNC
	;; Magazine Vol 1, N. 6 (Nov/ Dec '81, p. 38).
	;;
	;; This is a port to the Commodore PET, written in 6502 machine
	;; code, and including a timer as an added game element.
	
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

	;; PET BASIC 4.0 ROM routines and variables
	TIME=$8D	 ; Address of jiffy timer
	VIA_PCR=$E84C		; System variable noting character set in use
	GETIN=$FFE4		; Read keyboard
	CHROUT=$FFD2		; New ROM Clear Screen routine

	;; Page 0 temporary storage
	SEED=$50		; (2) Seed for random-number generator
	LOCN=$52		; (2) Holds screen address
	ROW=$54			; (1) Holds current print row
	COL=$55			; (1) Holds current print column
	STAR_CNT=$56		; (2) Holds number of stars on screen
	COUNT=$58		; (2) Temporary store for various counters
	CALC_STORE=$5B		; (8) Temporary storage for calculations
	STRING_PTR=$63		; (2) Pointer to PETSCII string to be printed

	;; Main game routine
HAMPSON:
	;; Initial setup
	lda #$0E		; Set active charset to Business
	sta VIA_PCR
	
	lda #00
	sta STAR_CNT		; Zero star counter
	sta STAR_CNT+1
	
	sta COUNT 		; Zero flip counter
	sta COUNT+1

	;; Print game board
	jsr SETUP_BOARD
	
	;; Query for game level
	jsr GET_LEVEL

	;; Reset clock
	sei
	lda #00
	sta TIME
	sta TIME+1
	sta TIME+2
	cli

	;; Randomly seed RNG (done now, so benefit from unpredictable
	;; time take for GET_LEVEL)
	jsr RAND0

	;; Randomly create starting board
	jsr RAND_BOARD

	;; Game loop
GLOOP:	jsr GET_COORD

	;; Check coordinate
	
	;; Flip tiles
	jsr FLIP9

	;; Check if done
	lda STAR_CNT
	ora STAR_CNT+1
	bne GLOOP

	;; New game
	jsr SOLVED

	;; Check if player wants to play another game
	jsr NEW_GAME
	beq HAMPSON
	
	;; If not, we're done
	rts

	;; Print time to screen in tenths of second, based on Jiffy
	;; clock.
	;;
	;; This version only works for times up to ~18 minutes
	;;
	;; On entry:
	;;
	;; On exit:
	;;   A - corrupted
CLOCK:	;Retrieve current time (pause interrupts to avoid misread)
	sei			; Pause interrupts
	lda TIME+2		; Read lowest byte of Jiffy clock
	sta CALC_STORE+2
	lda TIME+1		; Read second byte of Jiffy clock
	sta CALC_STORE+3
	cli			; Resume interrupts

	;; Convert time from 60th seconds to 10th seconds
	lda #6			; Set divisor to 6
	sta CALC_STORE
	lda #00
	sta CALC_STORE+1

	jsr DIV16		; Divide time by 6

	;; Set print position
	POSN=DISPLAY+22*40+36
	lda #<POSN
	sta LOCN
	lda #>POSN
	sta LOCN+1

	;; Retrieve fractions of second
	lda #10			; Divid by 10
	sta CALC_STORE
	lda #00
	sta CALC_STORE+1

	jsr DIV16		; Divide time by 10
	lda CALC_STORE+4	; Retrieve remainder
	jsr PRINT_DIGIT

	;; Print decimal place
	ldy #00
	lda #"."
	sta (LOCN),y
	dec LOCN
	
	;; Now retrieve four digits, one by one, and print
	lda #4 			; 4 digits
	sta CALC_STORE+6	; Store it
	
CL_LOOP:
	jsr DIV16

	lda CALC_STORE+4
	jsr PRINT_DIGIT

	dec CALC_STORE+6
	bne CL_LOOP

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
BC2A:	; Shift coordinate by (3,6) and then use C2A
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
FLIP9:	jsr BC2A		; Convert board coord to screen address

	ldx #03			; Three rows to flip
FL_ROW:	ldy #03			; Three columns to flip

FL_CHR:	lda (LOCN),y		; Retrieve current character
	eor #$0A		; Flip it (char 42 = */ 32 = SPACE)
	sta (LOCN),y		; Store it
	
	;; Update star count (we alway subtract one, but add two first
	;; if character is a star)
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

	;; Print string to screen
	;;
	;; On entry:
	;;   ROW, COL - location to print to
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

	;; Print (decimal) digit to screen and advance print loc
	;;
	;; On entry:
	;;   A - digit to be printed (0..9)
	;;   LOCN(2) - screen address to print to
	;;
	;; On exit:
	;;   A, Y - corrupted
	;;   LOCN(2) - next location to print to
PRINT_DIGIT:
	;; Print digit
	clc			; Convert A to PETSCII 
	adc #"0"		; code

	ldy #0	       		; Set index to zero
	
	sta (LOCN),y		; Print character

	;; Advance location
	dec LOCN
	
PD_DONE:
	rts			; Done

	
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
SETUP_BOARD:
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
	sta CALC_STORE
	lda #16
	sta CALC_STORE+1
	
SB_LOOP:
	;; Start with left column
	sec
	lda #20
	sbc CALC_STORE+1
	sta ROW
	lda #05
	sta COL

	lda CALC_STORE
	jsr PRINT_NUM

	;; Then right column
	sec
	lda #20
	sbc CALC_STORE+1
	sta ROW
	lda #35
	sta COL

	lda CALC_STORE
	jsr PRINT_NUM

	;; increment coordinate label (binary coded decimal)
	sed
	lda CALC_STORE
	clc
	adc #01
	sta CALC_STORE
	cld
	
	dec CALC_STORE+1
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

	;; Wait for user to stop pressing any keys. Useful to ensure
	;; do not read one keystroke as two separate key presses
	;;
	;; On entry:
	;;
	;; On exit:
	;;   A, X, Y - corrupted
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
	sta CALC_STORE
	lda #10
	sta CALC_STORE+1
	jsr DIVIDE
	lda CALC_STORE
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
	cmp #"0"		; Check range
	bcc GL_READ
	cmp #"9"+1
	bcs GL_READ

	;; Convert to level
	sec
	sbc #"0"-1

	pha			; Save A to stack for later

	tax			; X will be counter

	;; Flip count is 64x(LEVEL+1)
GL_STAR:
	lda #$40
	clc
	adc COUNT
	sta COUNT
	bcc GL_CONT
	inc COUNT+1

GL_CONT:
	dex
	bne GL_STAR
	
	pla			; Retrieve A from stack
	
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

	;; CHOOSE SKILL LEVEL (0-9)
GL_STR:	!scr "CHOOSE SKILL LEVEL (0-9)"
	!byte $FF

	;; Prompt user for coordinate of tile to flip.
	;;
	;; On entry:
	;;
	;; On exit:
	;;   ROW, COL - coordinates entered by user
GET_COORD:
	;; Print request to enter coordinate at (23,06)
	lda #23
	sta ROW
	lda #06
	sta COL
	
	lda #<GC_STR
	sta STRING_PTR
	lda #>GC_STR
	sta STRING_PTR+1

	jsr PRINT_STR

	;; Retrieve column value (A,..., Z)
GC_READ:
 	jsr CLOCK
	jsr GETIN
	beq GC_READ		; Repeat, if no key pressed

	;; On exit A should contain 65 ('A'), ..., 90 ('Z')
	cmp #"A"		; Check range
	bcc GC_READ
	cmp #"Z"+1
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
  	jsr CLOCK
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
	jsr CLOCK
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
	
	;; ENTER MOVE (COL FIRST)
GC_STR: !scr "ENTER MOVE (COL FIRST)       "
	!byte $FF	

SOLVED:
	;; Print request to enter coordinate at (23,06)
	lda #23
	sta ROW
	lda #06
	sta COL
	
	lda #<SO_STR
	sta STRING_PTR
	lda #>SO_STR
	sta STRING_PTR+1

	jsr PRINT_STR

	;; Wait for new key press
	jsr CHECK_NO_KEY	; Wait for no keys
	
SO_KEY:	jsr GETIN
	beq SO_KEY		; Repeat, if no key pressed
	
	rts
	
SO_STR:	!scr "GRID SOLVED               "
	!byte $FF
	

	;; Check if user wants another game
NEW_GAME:
	lda #01			; Reset Z flag
	
	rts

	
	;; Seed random-number generator using low byte of jiffy clock
	;; to provide some level of randomness, if using PRG file with
	;; auto-start
	;; 
	;; On entry:
	;;
	;; On exit:
	;;   SEED - set pseudo-randomly
	;;   A - corrupted
RAND0:
	lda $008F		; Retrieve low byte of 
	sta SEED		; seed from jiffy clock
	
	lda #01			; Set high byte to non-zero
	sta SEED+1		; to avoid risk of zero starting seed

	rts			; Done
	
	
	;; Pseudo-random-number generator, able to produce both 8-bit
	;; and 16-bit random numbers.
	;;
	;; See https://codebase64.org/doku.php?id=base:16bit_xorshift_random_generator
	;; for details of random-number generator
	;; 
	;; On entry:
	;;   SEED - set to RNG
	;;
	;; On exit:
	;;   A    - new random number (8-bit)
	;;   SEED - new random number (16-bit)
	;;
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

	;; 8-bit/8-bit integer division
	;; See http://6502org.wikidot.com/software-math-intdiv
	;; for details
	;;
	;; On entry:
	;;   CALC_STORE   - numerator
	;;   CALC_STORE+1 - denominator
	;;
	;; On exit:
	;;   CALC_STORE - quotient
	;;   A    - remainder
	;;  
DIVIDE:	lda #0
	ldx #8
	asl CALC_STORE
D1:	rol
	cmp CALC_STORE+1
	bcc D2
	sbc CALC_STORE+1
D2:	rol CALC_STORE
	dex
	bne D1

	rts

	;; 16-bit division
	;;
	;; On entry
	;;   CALC_STORE - divisor (little Endian)
	;;   CALC_STORE+2 - dividend (little Endian)
	;;
	;; On exit
	;;   CALC_STORE - divisor is preserved
	;;   CALC_STORE+2 - quotient (little Endian)
	;;   CALC_STORE+4 - remainder (little Endian)
	;;   A, X, Y - corrupted
	;; 
DIV16:	lda #0	        ;preset remainder to 0
	sta CALC_STORE+4
	sta CALC_STORE+5
	ldx #16	        ;repeat for each bit: ...

DIV_LP:	asl CALC_STORE+2	;dividend lb & hb*2, msb -> Carry
	rol CALC_STORE+3	
	rol CALC_STORE+4	;remainder lb & hb * 2 + msb from carry
	rol CALC_STORE+5
	lda CALC_STORE+4
	sec
	sbc CALC_STORE	;substract divisor to see if it fits in
	tay	        ;lb result -> Y, for we may need it later
	lda CALC_STORE+5
	sbc CALC_STORE+1
	bcc DIV_SK	;if carry=0 then divisor didn't fit in yet

	sta CALC_STORE+5	;else save substraction result as new remainder,
	sty CALC_STORE+4	
	inc CALC_STORE+2	;and INCrement result cause divisor fit in 1 times

DIV_SK:	dex
	bne DIV_LP	
	rts
