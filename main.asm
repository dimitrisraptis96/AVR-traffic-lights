.include "m16def.inc"

.def timecounter =	r20
.def temp = r16

.dseg
.org 0x100
.cseg
.org 0
rjmp RESET
.org 0x020
rjmp InterruptHandler

RESET:

	LDI	temp, low(RAMEND)
	OUT	SPL, temp
	LDI	temp, high(RAMEND)
	OUT	SPH, temp					; Stack pointer to end of RAM

	ldi temp, 0xFF
	out DDRB,temp					;PORTB becomes output port
	out PORTB,temp					;turn off all LEDS

	ldi temp,0x00
	out DDRD,temp					;PORTD input

	ldi temp, 0xF0
	out DDRA,temp					;PORTA first 4 output last 4 input
	ldi temp, 0xFF
	out DDRC,temp					;PORTC output
	
	ldi temp,16
	out TCNT1H,temp
	ldi temp,0
	out TCNT1L,temp											
	ldi temp,1<<TOIE1				;timer overflow interrupt enable 
	out TIMSK,temp					
	ldi temp,5						;clock prescaler=clk/1024 (256µsec) ~ 4000=1sec
	out TCCR1B,temp
	
	sei								;enable global interrupts
  
;##############################################################
;green=10,yellow=01,red=00,off=11
;##PORTD 1,2,3 = Flow1
;##PORTB 0,1,2 = Flow2
;##PORTB 3,4,5 = Flow3
;##001=flow a	010=flow b	100=flow c

Loop_main:

rcall pressedB

rjmp Loop_main

rcall strofiF
rcall delay3

;E,B green ## All else red ##Pedestrians A green
green_AO:
	ldi temp, 0b10100000  ;PORTC fanaria E,B, D,A
	out PORTC,temp
	ldi temp, 0b00001111  ;PORTA fanaria C kai F
	out PORTA,temp
	ldi temp, 0b11111001  ;PORTB pezoi A kai B
	out PORTB,temp
rcall delay3

rcall  yellow_all
rcall delay3

red_AO:
	ldi temp, 0b00001010  ;PORTC fanaria E,B, D,A
	out PORTC,temp
	ldi temp, 0b00001111  ;PORTA fanaria C kai F
	out PORTA,temp
	ldi temp, 0b11111001  ;PORTB pezoi A kai B
	out PORTB,temp

rcall delay3

rcall  yellow_all
rcall delay3

rjmp Loop_main

yellow_all:
		ldi temp, 0b01010101  ;PORTC fanaria E,B, D,A
		out PORTC,temp
		ldi temp, 0b01011111  ;PORTA fanaria C kai F
		out PORTA,temp
		ldi temp, 0b11110101  ;PORTB pezoi A kai B
		out PORTB,temp
		ret

notf1c1:
	in temp,pina
	com temp
	andi temp,0b00001000
	cpi temp,0b00001000
	brne notf1

notf1:	;if F1 not pressed
	;check if C1 pressed;
	in temp,pina
	com temp
	andi temp,0b00000100
	cpi temp,0b00000100
	brne pressedB

pressedB:
	;check if A pressed
	in temp,PINA
	andi temp,0b00000001
	cpi temp,0b00000001
	brne pressedB

	;A pressed give additional green to pedestrians
	ldi temp, 0b10100000  ;PORTC fanaria E,B, D,A
	out PORTC,temp

	ldi temp, 0b00001110  ;PORTA fanaria C kai F
	out PORTA,temp

	ldi temp, 0b11111001  ;PORTB pezoi A kai B
	out PORTB,temp

	ldi temp, 0b00000000  ;PORTB pezoi A kai B
	out PORTD,temp
	
	in temp,PINA
	out PORTC, temp
	jmp pressedB

	rcall delay3

	ldi timecounter,10
	ldi temp,16
	out TCNT1H,temp
	ldi temp,0
	out TCNT1L,temp
	xsloopPedsg:
		cpi timecounter,0
		brne xsloopPedsg
	ret

;E,F green ## All else red
strofiF:
	ldi temp, 0b10000000  ;PORTC fanaria E,B, D,A
	out PORTC,temp
	ldi temp, 0b00101111  ;PORTA fanaria C kai F
	out PORTA,temp
	ret

;E,F green ## All else red
strofiFportokali:
	ldi temp, 0b01000000  ;PORTC fanaria E,B, D,A
	out PORTC,temp
	ldi temp, 0b00011111  ;PORTA fanaria C kai F
	out PORTA,temp
	rcall delay3sec


;##Delays and timers##

;##############################
;yellow 3 sec for all
delay3sec:
; ============================= 
;    delay loop generator 
;     12000000 cycles:
; ----------------------------- 
; delaying 11999976 cycles:
          ldi  R17, $3E
WGLOOP20:  ldi  R18, $FD
WGLOOP21:  ldi  R19, $FE
WGLOOP22:  dec  R19
          brne WGLOOP22
          dec  R18
          brne WGLOOP21
          dec  R17
          brne WGLOOP20
; ----------------------------- 
; delaying 24 cycles:
          ldi  R17, $08
WGLOOP23:  dec  R17
          brne WGLOOP23
; ============================= 
ret

delay3:
    ldi  r18, 122
    ldi  r19, 193
    ldi  r20, 130
L1: dec  r20
    brne L1
    dec  r19
    brne L1
    dec  r18
    brne L1
    rjmp PC+1

	ret	


InterruptHandler:
;each time we are here 1 second has passed
;decrease only the time counter so the main programm
;can decide corresponding to it  and return from the
;interrupt

dec timecounter
ldi temp,255
out TCNT1H,temp
ldi temp,210
out TCNT1L,temp
reti
