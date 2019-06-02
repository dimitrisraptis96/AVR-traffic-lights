.include "m16def.inc"

.def temp = r16
.def overflow_counter = r21
.def current_state = r22
.def which_button = r23

; Init stack pointer
.macro init_stack
	ldi @0, low(@1)
	out spl, @0
	ldi @0, high(@1)
	out sph, @0
.endmacro

	; Init Timer/Counter Register 1 with 0xf000 = 61440 
	; f=4MHz, prescaler=1024 MAX=65535
	; Thus the delay until overflow is (MAX - 61440) * prescaler / f = 1sec)
.macro start_timer
	ldi temp, 0xf0
	out TCNT1H, temp
	ldi temp, 0xbd
	out TCNT1L, temp
.endmacro

.dseg
.org 0x100

.cseg
.org $0
rjmp reset
.org $10
rjmp interrupt_handler

reset:
	init_stack temp, RAMEND

	; =============================
	; Init PORTS
	; =============================
	; PORTA 
	; Bits 0-3 input SW(A12,B12,C,F) & 4-7 output (F,C)
	ldi temp, 0xF0
	out DDRA, temp
	ldi temp, 0xFF
	out PINA, temp

	; PORTB
	; Bits 0-5 input (FLOWS 2-3)				
	ldi temp, 0x00
	out DDRB, temp					
	out PORTB, temp ; handle ISP issue

	; PORTC 
	; Bits 0-7 output (E-B-D-A)
	ldi temp, 0xFF
	out DDRC, temp					

	; PORTD
	; Bits 0-2 Input (FLOW 1)
	; Bits 4-6 Output (Bit4 A12 and Bit5 B12)
	ldi temp, 0b00110000
	out DDRD, temp
	ldi temp, 0x00
	out PORTB, temp

	; =============================
	; Set up Timer1 
	; =============================
	start_timer

	; Timer Overflow interrupt enable 
	ldi temp, 1<<TOIE1			
	out TIMSK, temp

	; Devide clock by 1024 
	ldi temp, 0b00000101	
	out TCCR1B, temp

	; Enable Interrupts
	sei	

	ldi overflow_counter, 0
	clr temp
	clr current_state

	ldi current_state, 1

main:
	rcall switch_current_state

	rjmp main

switch_current_state: 
	cpi current_state, 0
	breq  case_orange
	cpi current_state, 1
	breq case_state_1
	cpi current_state, 2
	breq case_state_2
	cpi current_state, 3
	breq case_state_3
	cpi current_state, 4
	breq case_state_4
	cpi current_state, 5
	breq case_state_5
	ret

case_orange:
	rjmp load_state_orange		; open all the orange LEDS
	; Handling next state here
	;rjmp check_A12				; check if a SW is pressed, otherwise continue with the next state

case_state_1:
	rcall load_state_1
	rjmp end_of_switch

case_state_2:
	rcall load_state_2
	rjmp end_of_switch

case_state_3:
	rcall load_state_3
	rjmp end_of_switch

case_state_4:
	rcall load_state_4
	rjmp end_of_switch

case_state_5:
	rcall load_state_5
	rjmp end_of_switch

end_of_switch: 
	; Light orange lights after each state ended
	rjmp case_orange


; ======================================================
; Checking PULL UP buttons and calculate next state here
; ======================================================
in temp, PINA

check_A12:
	in temp, PINA
	sbrs temp, 0 
	rjmp set_state_2 				; is A12 pressed
	rjmp check_B12					; above is skipped if A12 is not pressed
	

check_B12:
	in temp, PINA
	sbrs temp, 1
	rjmp set_state_1 				; is B12 pressed
	rjmp check_C1					; above is skipped if B12 is not pressed

check_C1:
	in temp, PINA
	sbrs temp, 2 
	rjmp set_state_4 				; is C1 pressed
	rjmp check_F1					; above is skipped if C1 is not pressed


check_F1:
	in temp, PINA
	sbrs temp, 3 
	rjmp set_state_3				; is F1 pressed
	rjmp check_next_normal_state	; above is skipped if C1 is not pressed


check_next_normal_state:
	; Next state is 1 or B
	cpi current_state, 1
	breq set_state_2
	rjmp set_state_1


set_state_1:
	ldi current_state, 1
	rjmp main

set_state_2:
	ldi current_state, 2
	rjmp main

set_state_3:
	ldi current_state, 3
	rjmp main

set_state_4:
	ldi current_state, 4
	rjmp main

set_state_5:
	ldi current_state, 5
	rjmp main

; ===================
; Define some states:
; ===================
; state_1: A,D green 	B,C,E,F red 	& 	pedestrians A12 red 	B12 green
; state_2: B,E green 	A,C,D,F red 	& 	pedestrians A12 green 	B12 red
; state_3: E,F green 	A,B,C,D,F red 	& 	pedestrians A12 red 	B12 red
; state_4: B,C green 	A,D,E,F red 	& 	pedestrians A12 green 	B12 red
; state_5: F green 		A,B,C,D,E red 	& 	pedestrians A12 red 	B12 green

load_state_orange:
	ldi temp, 0b01010101  ; E,B red & D,A green
	out PORTC,temp
	ldi temp, 0b00001111  ; C,F red
	out PORTA,temp
	ldi temp, 0b00000000  ; A12,B12 flashing
	out PORTD,temp
	rcall delay_3_seconds
	rcall check_A12
	;rjmp select_mode
	
	;rjmp check_A12

select_mode: 
	cpi which_button, 0
	breq  check_next_normal_state
	cpi which_button, 1
	breq set_state_2
	cpi which_button, 2
	breq set_state_1
	cpi which_button, 3
	breq set_state_4
	cpi which_button, 4
	breq set_state_3
	
	rjmp main
	

; Traffic Lights:	A,D green 	B,C,E,F red
; Pedestrians:		A12 red 	B12 green
load_state_1:
	ldi temp, 0b00001010  ; E,B red & D,A green
	out PORTC,temp
	ldi temp, 0b00001111  ; C,F red
	out PORTA,temp
	ldi temp, 0b00010000  ; A12 red & B12 green
	out PORTD,temp

	ldi overflow_counter, 2
	start_timer
	timer_loop_1:
		cpi overflow_counter,0
		brne timer_loop_1
	ret

; Traffic Lights:	E,B green 	A,B,C,D,F red
; Pedestrians:		A12 green 	B12 red
load_state_2:
	ldi temp, 0b10100000  ; E,B green, D,A red
	out PORTC,temp
	ldi temp, 0b00001111  ; C,F red
	out PORTA,temp
	ldi temp, 0b00100000  ; A12 green & B12 red
	out PORTD,temp

	ldi overflow_counter, 2
	start_timer
	timer_loop_2:
		cpi overflow_counter,0
		brne timer_loop_2
	ret

; Traffic Lights:	E,F green 	A,B,C,D,F red
; Pedestrians:		A12 red 	B12 red
load_state_3:
	ldi temp, 0b10000000  ; E green,B, D,A red
	out PORTC,temp
	ldi temp, 0b00101111  ; C red,F green
	out PORTA,temp
	ldi temp, 0b00110000  ; A12 red & B12 red
	out PORTD,temp

	ldi overflow_counter, 2
	start_timer
	timer_loop_3:
		cpi overflow_counter,0
		brne timer_loop_3
	ret

; Traffic Lights:	B,C green 	A,D,E,F red
; Pedestrians:		A12 green 	B12 red
load_state_4:
	ldi temp, 0b00100000  ; E red, B green & D,A red
	out PORTC,temp
	ldi temp, 0b10001111  ; C green,F red
	out PORTA,temp
	ldi temp, 0b00100000  ; A12 green & B12 red
	out PORTD,temp

	ldi overflow_counter, 2
	start_timer
	timer_loop_4:
		cpi overflow_counter,0
		brne timer_loop_4
	ret

; Traffic Lights:	F green 	A,B,C,D,E red
; Pedestrians:		A12 red 	B12 green
load_state_5:
	ldi current_state, 2
	ldi temp, 0b00000000  ; E,B,D,A red
	out PORTC,temp
	ldi temp, 0b00101111  ; C red ,F green
	out PORTA,temp
	ldi temp, 0b00010000  ; A12 red & B12 green
	out PORTD,temp

	ldi overflow_counter, 2
	start_timer
	timer_loop_5:
		cpi overflow_counter,0
		brne timer_loop_5
	ret

; =======================================
; Interrupt and 3sec delay handlers above
; =======================================
interrupt_handler:
	dec overflow_counter

	ldi temp,0xf0
	out TCNT1H,temp
	ldi temp,0xbd
	out TCNT1L,temp

	; check if any button is pressed
	in temp, PINA
	ldi which_button, 1
	sbrs temp, 0
	reti					; A12 button is pressed
	ldi which_button, 2
	sbrs temp, 0
	reti					; B12 button is pressed
	in temp, PINA
	ldi which_button, 3
	sbrs temp, 0
	reti					; C1 button is pressed
	in temp, PINA
	ldi which_button, 4
	sbrs temp, 0
	reti					; F1 button is pressed

	ldi which_button, 0		;no button is pressed so load 0
	reti

; A12,B12 flashing
flash_orange: 
	in temp, PORTD 
	com temp
	andi temp, 0b00110000 	; masking A12 and B12 bits
	out PORTD,temp
	ret

delay_3_seconds:
    ldi  r18, 61
    ldi  r19, 225
    ldi  r20, 64
	rcall flash_orange ; should have used the timer interrupt and call the flash_orange every 1 sec
L1: dec  r20
    brne L1
    dec  r19
    brne L1
    dec  r18
    brne L1
    rjmp PC+1
    ret

.exit
