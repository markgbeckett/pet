DISP:	EQU $8000		; Start of display buffer
	
	ORG $033A		; Start of Tape Buffer #2

	LDX #$C8		; 200d = 5x40 chars
	LDA #'*'

LOOP:	STA DISP, X		; Write character
	DEX			; Dec counter
	BNE LOOP

	;; Done
	BRK
