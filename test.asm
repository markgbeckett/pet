!to "test.prg",cbm
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

start:
	lda #01
	sta $8000
	rts
