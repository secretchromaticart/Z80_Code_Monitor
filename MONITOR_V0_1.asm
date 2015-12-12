;****************************************************************
;			    'CODE' MONITOR
; 					V0.1
;****************************************************************

;FOR Z80 COMPUTER - 8 INPUT AND 8 OUTPUT PORTS AVAILABLE
;ROM ADDRESS 0000H - 7FFFH
;RAM ADDRESS 8000H - FFFFH

;TO IMPLEMENT:
;OPTIMISE KEY_IN ROUTINE
;COLD/WARM START SEQUENCES FOR REGISTER SAVE AND USER RESTARTS
;REGISTER VIEW/EDIT SEQUENCE

;****************************************************************
;			HARDWARE CONSTANTS
;****************************************************************

KEY_IN_ADD EQU 00H ;INPUT PORT OF KEYBOARD
DATA_DIS_OUT_ADD EQU 00H ;DISPLAY OUTPUT PORTS
LSB_DIS_OUT_ADD EQU 01H
MSB_DIS_OUT_ADD EQU 02H

;****************************************************************
;			COLD START
;****************************************************************


COLD_START: ;PROPER RESTART SEQUENCE TO BE ADDED
	LD SP,0FFFFH
	


;****************************************************************
;			MAIN SCRIPT
;****************************************************************

;DISPLAY DECODE MESSAGE TO SIGNAL COMMAND MODE
COMMAND_MODE:
	;DISPLAY DECODE MESSAGE TO SIGNAL COMMAND MODE
	LD A,0C0H
	OUT (MSB_DIS_OUT_ADD),A
	LD A,0DEH
	OUT (LSB_DIS_OUT_ADD),A
	LD A,00H
	OUT (DATA_DIS_OUT_ADD),A

CODE_MENU:
	;GET USER INPUT: REQUIRES SHIFT+NO TO ENTER MODE
	LD HL,0000H
	LD C,00H ;8-BIT INPUT
	CALL KEY_IN
	BIT 6,C ;HAS NEXT BEEN PRESSED?
	JP Z,COMMAND_MODE ;NO? RETURN TO COMMAND MODE
SHIFT_KEY_TESTS:
	LD A,L
	CP 01H
	JP Z,MEMORY_EDITOR ;1 PRESSED SO MEM EDIT
	CP 02H ;2 PRESSED SO DO EXE FUNCTION
	JP Z,EXE_FROM_MENU
	CP 03H ;3 PRESSED SO REGISTER EDIT
	JP Z,REGISTER_EDIT
	JP CODE_MENU
	
;****************************************************************
;			MEMORY VIEW/EDIT
;****************************************************************
	
MEMORY_EDITOR:

GET_START_ADDRESS:
	LD A,00H
	OUT (MSB_DIS_OUT_ADD),A
	OUT (LSB_DIS_OUT_ADD),A
	LD A,0AAH
	OUT (DATA_DIS_OUT_ADD),A ;SHOW AA PROMPT
	LD HL,0000H
	LD C,80H ;16-BIT NO.
	CALL KEY_IN
	BIT 6,C ;HAS NEXT BEEN PRESSED?
	JP Z,GET_START_ADDRESS
	
	LD A,(HL) ;SHOW FIRST VALUE
	OUT (DATA_DIS_OUT_ADD),A
	
	LD D,H
	LD E,L ;de nOW HOLDS ADDRESS VALUE
	JP GET_MEM_VALUE
	
INC_MEM_VALUE:

	INC DE ;GOTO NEXT VALUE
	
	LD A,D
	OUT (MSB_DIS_OUT_ADD),A
	LD A,E
	OUT (LSB_DIS_OUT_ADD),A
				
GET_MEM_VALUE:

	LD A,(DE) ;GET NEXT DATA VALUE
	OUT (DATA_DIS_OUT_ADD),A
	
	LD L,A
	LD C,40H ;8-BIT NO and rotate
	PUSH DE
	CALL KEY_IN_NOT_FIRST
	POP DE
	BIT 4,C ;HAS MENU BEEN PRESSED?
	JP NZ,COMMAND_MODE
	BIT 6,C ;HAS NEXT BEEN PRESSED?
	JP Z,GET_MEM_VALUE
	
	;SAVE VALUE
	LD A,L
	LD (DE),A
	
	JP INC_MEM_VALUE
	
REGISTER_EDIT:
	;MENU TEST ONLY
	LD A,0DDH
	OUT (DATA_DIS_OUT_ADD),A
	OUT (MSB_DIS_OUT_ADD),A
	OUT (LSB_DIS_OUT_ADD),A
	JP CODE_MENU ;NORMALLY COMMAND MODE

EXE_FROM_MENU: 	;SHIFT + 2, REQUEST ADD THEN RUN		
	
	LD A,00H
	OUT (MSB_DIS_OUT_ADD),A
	OUT (LSB_DIS_OUT_ADD),A
	LD A,0EEH
	OUT (DATA_DIS_OUT_ADD),A
	LD HL,0000H
	LD C,80H ;16-BIT NO.
	CALL KEY_IN
	BIT 5,C ;HAS EXE BEEN PRESSED?
	JP Z,EXE_FROM_MENU 
	;COMMANDS HAVE BEEN ENTERED CORRECT
	PUSH HL
	RET
	

;****************************************************************
;			KEYBOARD SUBROUTINES
;****************************************************************

;KEY_IN - INPUT NUMBER AND RETURN THROUGH NEXT OR EXE OR MENU
;AND NUMBER
;GETS A 16-BIT NUMBER FROM THE KEYBOARD AND THEN OUTPUTS IT 
;ON DISPLAY.
;INPUT: IN REGISTER C (BIT 7: 0 = 8 BIT, 1 = 16 BIT) I.E. ADDRESS
;OR DATA DISPLAY
;OUTPUT: HL (MSB CAN BE IGNORED) AND C RETURNS NEXT, EXE OR MENU

;HARDWARE INPUTS: 
;UPPER NIBBLE:
;BIT 7: 0 = NO NUMBER PRESENT, 1 = READ STROBE (INCLUDES DEBOUNCING)
;BIT 6: 0 = MENU KEY PRESSED, 1 = MENU KEY NOT PRESSED
;BIT 5: 0 = NEXT KEY NOT  PRESSED, 1 = NEXT KEY PRESSED
;BIT 4: 0 = EXE KEY NOT PRESSED, 1 = EXE KEY PRESSED
;LOWER NIBBLE OF KEYBOARD PORT HAS USERS NUMBER


KEY_IN:
	RES 6,C ;SET FIRST KEY
KEY_IN_NOT_FIRST:
	IN A,(KEY_IN_ADD)
	BIT 5,A ;HAS NEXT BEEN PRESSED?
	JP NZ,NEXT_KEY_IN
	BIT 4,A ;HAS EXE BEEN PRESSED?
	JP NZ,EXE_KEY_IN
	BIT 6,A ;HAS SHIFT BEEN PRESSED?
	JP Z,MENU_KEY_IN
	BIT 7,A ;IF STROBE IS NOT SET ZERO FLAG IS SET
	JP Z,KEY_IN_NOT_FIRST
	
	PUSH AF
	
NUMBER_RELEASE: ;STROBE IS SET SO WAIT UNTIL ITS RELEASE
	IN A,(KEY_IN_ADD)
	BIT 7,A
	JP NZ,NUMBER_RELEASE
		
	POP AF
	LD B,0FH
	AND B ;NEXT NUMBER IN LOWER NIBBLE OF A
	
	;IS THIS THE FIRST NUMBER
	BIT 6,C
	JP Z,SKIP_SHIFT
	
	;SHIFT VALUE IN HL BY FOUR TO THE LEFT
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
SKIP_SHIFT:
	LD E,A ;ADD NEW NUMBER TO LOWEST END
	LD D,00H
	ADD HL,DE
	
	SET 6,C ;A NUMBER HAS BEEN PRESSED NOW
	
	;TEST TO SEE IF A 16-BIT NUMBER IS DISPLAYED
	
	;NO? - OUTPUT ON DATA DISPLAY
	BIT 7,C
	LD A,L
	JP NZ,SHOW_ADD_DIS
	
SHOW_DATA_DIS:
	
	OUT (DATA_DIS_OUT_ADD),A
	JP KEY_IN_NOT_FIRST


SHOW_ADD_DIS:
	
	OUT (LSB_DIS_OUT_ADD),A
	LD A,H
	OUT (MSB_DIS_OUT_ADD),A
	JP KEY_IN_NOT_FIRST
	
		
NEXT_KEY_IN:
	IN A,(00H)
	BIT 5,A ;IF NEXT IS PRESSED ZERO FLAG IS SET
	JP Z,NEXT_KEY_IN
	
	;NEXT PRESSED
	
	CALL DEBOUNCE_DELAY
	
	IN A,(00H)
	BIT 5,A 
	JP Z,NEXT_KEY_IN
	
	;STILL PRESSED? - THEN WAIT FOR RELEASE
	
NEXT_KEY_RELEASE:
	IN A,(00H)
	BIT 5,A
	JP NZ,NEXT_KEY_RELEASE
	;NEXT KEY PRESSED AND RELEASED - SET FLAG ON C
	SET 6,C
	RET
		
EXE_KEY_IN:
	IN A,(00H)
	BIT 4,A ;IF EXE IS PRESSED ZERO FLAG IS SET
	JP Z,EXE_KEY_IN
	
	;NEXT PRESSED
	
	CALL DEBOUNCE_DELAY
	
	IN A,(00H)
	BIT 4,A 
	JP Z,EXE_KEY_IN
	
	;STILL PRESSED? - THEN WAIT FOR RELEASE
	
EXE_KEY_RELEASE:
	IN A,(00H)
	BIT 4,A
	JP NZ,EXE_KEY_RELEASE
	;NEXT KEY PRESSED AND RELEASED - SET FLAG ON C
	RES 6,C
	SET 5,C
	RET

MENU_KEY_IN:
	IN A,(00H)
	BIT 6,A ;IF NEXT IS PRESSED ZERO FLAG IS SET
	JP NZ,MENU_KEY_IN
	
	;NEXT PRESSED
	
	CALL DEBOUNCE_DELAY
	
	;IN A,(00H)
	;BIT 5,A 
	;JP Z,MENU_KEY_IN
	
	;STILL PRESSED? - THEN WAIT FOR RELEASE
	
MENU_KEY_RELEASE:
	IN A,(00H)
	BIT 6,A
	JP Z,MENU_KEY_RELEASE
	;NEXT KEY PRESSED AND RELEASED - SET FLAG ON C
	RES 6,C
	SET 4,C
	RET

DEBOUNCE_DELAY: 
	;NOP ;UNCOMMENT FOR IDE DEBUGGING
	;RET
	PUSH BC
	PUSH DE
	LD BC, 0010h
OUTER:
	LD DE, 0100h
INNER:
		DEC DE
		LD A,D
		OR E
		JP NZ, INNER
		DEC BC
		LD A, B
		OR C
		JP NZ, OUTER
		POP DE
		POP BC
		RET

.ORG 4000H

;TEST PROGRAM TO RUN
;SO EXE COMMAND CAN BE TESTED

EXECUTE:
	LD A,0AAH
	OUT (DATA_DIS_OUT_ADD),A
	OUT (MSB_DIS_OUT_ADD),A
	OUT (LSB_DIS_OUT_ADD),A
	JP EXECUTE
COFFEE:
	LD A,0C0H
	OUT (MSB_DIS_OUT_ADD),A
	LD A,0FFH
	OUT (LSB_DIS_OUT_ADD),A
	LD A,0EEH
	OUT (DATA_DIS_OUT_ADD),A
	JP COFFEE

END

Z-80 Computer Hardware description available online.
