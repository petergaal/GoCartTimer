
; This is a program for a static box, originally dated 13/01/2004

.include "2313def.inc"

.DSEG

;variable for saving time in human readable format
;       "123456789012345678"
;        65535:23:59:59:999 
timebuf:	.byte 18

.equ timebuf_DD  = timebuf
.equ timebuf_HH  = timebuf+6
.equ timebuf_MM  = timebuf+9
.equ timebuf_SS  = timebuf+12
.equ timebuf_SSS = timebuf+15

;time will be saved here:
; R20 - "twohundredths" of second
; R21 - seconds
; R22 - minutes
; R23 - hours
; R25:R24 - days (will be as uint16)

prev_F1:		.byte 1

serialbuf:		.byte 32		;(32 byte sending buffer)
ser_head:		.byte 1
ser_tail:		.byte 1


.def OldResult = R9
.def NewResult = R10

.set LED_length = 1000/5

.CSEG

		rjmp	RESET		;Reset handler
		rjmp    EXT_INT0	;IRQ0 handler
		rjmp    EXT_INT1	;IRQ1 handler
		rjmp	TIM1_CAPT1	;Timer1 capture handler
		rjmp	TIM1_COMP1	;Timer1 compare handler
		rjmp	TIM1_OVF	;Timer1 overflow handler
		rjmp	TIM0_OVF	;Timer0 overflow handler
		rjmp	UART_RXC	;UART RX Complete handler
		rjmp	UART_DRE	;UART Empty handler
		rjmp	UART_TXC	;UART TX Complete handler
		rjmp	ANA_COMP	;Analog comparator handler


		
EXT_INT0:
EXT_INT1:
TIM1_CAPT1:
TIM1_COMP1:
TIM1_OVF:
TIM0_OVF:
UART_RXC:
UART_DRE:
UART_TXC:
ANA_COMP:
		
		reti



; inputs:
; R20 - "twohundredths" of second
; outputs:
; will write time to timebuf_SSS in ms units
; changes registers: R16,R17,R26

convtimebuf_SSS:
		ldi R17,'0'	;we will load '0' char by default
		mov R16,R20 ; load value
		lsr R16		;divide by two
		brcc convtimebuf_SSS2
		ldi R17,'5'	;if carry bit left, then it's an odd number and the last number will be 5 (ms)

convtimebuf_SSS2:
		sts timebuf_SSS+2,R17
					;we have here in R16 the numeric value
		ldi R26,timebuf_SSS
;we continue with the code in the next function (no return magic)



;inputs: 
;R16 - numeric value
;X (R27:R26) is the address (pointer), where we will put the result
;outputs:
;will save 2 bytes at the address X (R27:R26) after each other
;changes registers: R17, X (R26,R27), R16
; it's a function similar to C function printf("%2.2d",R16)

convtimebuf2:
		ldi R17,'0'

convtimebuf2_a:
		cpi R16,10
		brlo convtimebuf2_b
		subi R16,10
		inc R17
		rjmp convtimebuf2_a

convtimebuf2_b:
		st X+,R17
		ldi R17,'0'
		add R17,R16
		st X+,R17
		ret



;inputs: 
;R24,R25 - it's int16 (16 bit integer)
;outputs:
;will put 5 bytes to memory at address timebuf_DD
;changes registers: R16, R17, R18, X (R26,R27)
; it's a function similar to C function printf("%5.5d",int16)

convtimebuf_DDDDD:
		ldi R18,'0'						;load zero ascii char ('0')
		mov R16,R24
		mov R17,R25
		ldi R26,timebuf_DD				;load the address of timebuf_DD

convtimebuf_DDDDD_10000:
		cpi R17,39						;10000 div 256=39 (High byte)
		brlo convtimebuf_DDDDD_10000b
		brne convtimebuf_DDDDD_10000a	;if doesn't equal, then must be only more
		cpi R16,16						;if equals, then we also test the lower byte, which is 16
		brlo convtimebuf_DDDDD_10000b	;if it's less, go further

convtimebuf_DDDDD_10000a:				;it jumped here, if the higher byte is more than 39
		subi R16,16						;subtract 16 from lower byte
		sbci R17,39						;subtract 39 from higher byte (also with carry)
		inc R18							;will increment 1 at the digit of ten thousands
		rjmp convtimebuf_DDDDD_10000

convtimebuf_DDDDD_10000b:
		st X+,R18						;store the byte at address X and increment X
		ldi R18,'0'						;load zero ascii char ('0')
				
convtimebuf_DDDDD_1000:
		cpi R17,3						;1000 div 256=3 (High byte)
		brlo convtimebuf_DDDDD_1000b
		brne convtimebuf_DDDDD_1000a	;if doesn't equal, then must be only more
		cpi R16,232						;if equals, then we also test the lower byte, which is 232
		brlo convtimebuf_DDDDD_1000b	;if it's less, go further

convtimebuf_DDDDD_1000a:				;it jumped here, if the higher byte is more
		subi R16,232					;subtract 232 from lower byte
		sbci R17,3						;subtract 3 from higher byte (also with carry)
		inc R18							;will increment 1 at the digit of thousands
		rjmp convtimebuf_DDDDD_1000

convtimebuf_DDDDD_1000b:
		st X+,R18						;store the byte at address X and increment X
		ldi R18,'0'						;load zero ascii char ('0')

convtimebuf_DDDDD_100:
		cpi R17,0						;100 div 256=0 (High byte)
		brne convtimebuf_DDDDD_100a		;if doesn't equal, then must be only more
		cpi R16,100						;if equals, then we also test the lower byte, which is 100
		brlo convtimebuf_DDDDD_100b		;if it's less, go further

convtimebuf_DDDDD_100a:					;it jumped here, if the higher byte is more
		subi R16,100					;subtract 100 from lower byte
		sbci R17,0						;subtract 0 from higher byte (also with carry)
		inc R18							;will increment 1 at the digit of thousands
		rjmp convtimebuf_DDDDD_100

convtimebuf_DDDDD_100b:
		st X+,R18						;store the byte at address X and increment X
		rjmp convtimebuf2				;handle the rest with function convtimebuf2 (again trick with a return)



;inputs:
;R16 - pulse count
;outputs:
;nothing
;changes registers: R16,R17

send1:	sbi PORTD,2		;switch on IR LED
		ldi R17,10
send1b:	dec R17
		brne send1b		;wait just exactly to make a 56 kHz signal for 3.6864 MHz CPU clock 
		nop
		cbi PORTD,2		;switch off the IR LED
		ldi R17,9
send1c:	dec R17
		brne send1c		;wait also during the switched off IR LED
		nop
		dec R16			;counting the pulses
		brne send1		;if still we have some, send another pulse
		ret				;otherwise we are finished, return back from the function



;inputs: 
;R16 - pulse count
;outputs:
;nothing
;changes registers: R16,R17

send0:	cbi PORTD,2		;switch off the IR LED (the rest is similar to function above)
		dec R16
		breq send0d
send0b:	ldi R17,21
send0c:	dec R17
		brne send0c
		nop
		dec R16
		brne send0b
send0d:	ldi R17,10
send0e:	dec R17
		brne send0e
		nop
		ret



;inputs: time registers
;outputs: converted number in the timebuf array
;changes registers: R16,R17, X (R26,R27)

timetobuf:
		ldi R17,':'
		sts timebuf_HH-1,R17
		sts timebuf_MM-1,R17
		sts timebuf_SS-1,R17
		ldi R17,'.'
		sts timebuf_SSS-1,R17
		rcall convtimebuf_SSS	;format number (byte) for the ms part

		ldi R26,timebuf_SS
		mov R16,R21
		rcall convtimebuf2	;format number (byte) for the seconds part

		ldi R26,timebuf_MM
		mov R16,R22
		rcall convtimebuf2	;format number (byte) for the minutes part

		ldi R26,timebuf_HH
		mov R16,R23
		rcall convtimebuf2	;format number (byte) for the hours part

		rcall convtimebuf_DDDDD	;format numer (2 bytes, 16 bits unsigned) for the days part (5 digits)
		ret



;inputs:
;R16 - fill value
;R17 - fill count
;X - start adress
;outputs: filled memory
;changes registers: R16,R17, X (R26,R27)

fillmem:
		st X+,R16
		dec R17
		brne fillmem
		ret

;inputs: nothing
;outputs: nothing
;changes registers: R16

serial_init:
		ldi R16,(1<<RXEN)+(1<<TXEN)	;set it to RX and TX Enable
		out UCR,R16					;won't have any interrupts
		ldi R16,5					;serial port baud rate at 38400 bit/s
		out UBRR,R16				;115200=1, 38400=5, 19200=11, 9600=23
		ret							

;inputs:
;from memory about serial
;vystupy: sends to serial port
;changes registers: R16,R17,X (R26,R27)

serial_send:
		sbis USR,UDRE			;first check, if the register is empty
serial_send02:
								;from other function (just to save space); not used now
		ret

		lds R16,ser_head		;load head
		lds R17,ser_tail		;and tail

serial_send01:
		cp R16,R17				;if head and tail equals
		breq serial_send02		;don't send anything
		ldi R26,serialbuf
		add R26,R16				;load byte from address ser_head
		ld R17,X
		out UDR,R17				;send character to serial port
		inc R16					;increment address of head
		andi R16,31				;mask address to value 0-31
		sts ser_head,R16		;save address to memory
		rjmp serial_send		;and do it from the beginning


;inputs:
; R16 - byte to send
;outputs: nothing (sends a byte to serial port)
;changes registers: R16,R17,R18,X (R26,R27)

sendbyte:
		lds R17,ser_head		;load head
		lds R18,ser_tail		;and tail
		sub R17,R18				;subtract R17 and R18 (should be vice versa, but we will save a register and some instructions
		dec R17					
		andi R17,31				;mask it for the desired range
		breq sendbyte01			;if the buffer is full, jump to the end (originally jumped to serial_send02)
		ldi R26,serialbuf		;load address of sendbuf
		add R26,R18				;add tail index tail
		st X,R16				;store byte to memory
		inc R18					;move tail index
		andi R18,31				;mask it for the desired range
		sts ser_tail,R18		;store tail from the register
;		rjmp serial_send		;send character out also to a serial port immediately (not used anymore)
sendbyte01:
		ret						;I put this for serial_send (ret instruction) ; not used anymore, just a normal ret



;inputs: nothing
;outputs: nothing
;will send out time to the serial port
;changes registers: R16,R26 + what is changed in sendbyte function

sendtime:
		ldi R26,timebuf
sendtime01:
		ld R16,X+
		push R26				;push X to stack
		rcall sendbyte			;send char
		pop R26
		cpi R26,timebuf+18		;if we didn't reach the end of the buffer
		brne sendtime01			;send another chars
		ldi R16,13				;load char CR (\r)
		rcall sendbyte			;send char
		ldi R16,10				;load char LF (\n)
		rcall sendbyte			;send char
		ret

;inputs: nothing
;outputs: in R16 - remaining free bytes in buffer
;changes registers: R16,R17

buf_free:
		lds R16,ser_head		;load head
		lds R17,ser_tail		;and tail
		sub R16,R17				;subtract R18 and R17
		dec R16
		andi R16,31
		ret

;inputs: nothing
;outputs: nothing
;sets up the LED on and off states (times)
;meni registre: R0,R1,R2,R3

handlecnt:
		tst R0				;test range
		breq handlecnt0		;if zero, move on
		cbi PORTB,0			;otherwise switch on the LED
		dec R0				;decrement the number
		brne handlecnt0		;if zero,
		sbi PORTB,0			;switch off the LED

handlecnt0:					;the same applies to other LED (4 total)
		tst R1
		breq handlecnt1
		cbi PORTB,1
		dec R1
		brne handlecnt1
		sbi PORTB,1

handlecnt1:
		tst R2
		breq handlecnt2
		cbi PORTB,2
		dec R2
		brne handlecnt2
		sbi PORTB,2

handlecnt2:
		tst R3
		breq handlecnt3
		cbi PORTB,3
		dec R3
		brne handlecnt3
		sbi PORTB,3

handlecnt3:
		ret


RESET:
		ldi R16, LOW(RAMEND)
		out SPL,R16

		clr R27			;set high byte of X to zero
		ldi R26,$60		;clear also the RAM
		clr R16
		ldi R17,124		;124 bytes - just to not overwrite the stack by accident
		rcall fillmem	;empty the memory

		rcall serial_init	;set up the serial port

reset1:	
		

		ldi R16,5
		out TCCR1B,R16	;CLK=CK/1024
		ldi R16,15
		out DDRB,R16	;Port B, lower 4 bits to output
		ldi R16,255
		out PORTB,R16	;also with pull-up resistors
		mov R0,R16
		mov R1,R16
		mov R2,R16
		mov R3,R16

		ldi R16,4
		out DDRD,R16	;D2 to vystup, rest to input
		ldi R16,251
		out PORTD,R16	;also pull-up resistors on each input

		clr R25			;reset days (H)
		clr R24			;reset days (L)
		clr R23			;reset hours
		clr R22			;reset minutes
		clr R21			;reset seconds
		clr R20			;reset 1/200s of seconds
		clr OldResult	;reset old result
		clr NewResult	;reset new result

		out TCCR1A,R20	;no PWM, no Output Compare
		out TCNT1L,R20	;counter will run with a counting frequency of
		out TCNT1H,R20	;3.6864/1024=3600, which is 3,6 kHz
		rcall timetobuf	;fill the timebuf with zero values


main01:	in R16,TCNT1L	;load the counter value
		cpi R16,18		;if it's less than 18, jump
		brlo main03
		
		subi R16,18		;we should have an interval each 5 ms
		out TCNT1L,R16	;store the new counter value

		
		inc R20			;increment the value of 1/200 seconds
		rcall handlecnt	;call the handler of LED counters

main01a:cpi R20,200		;compare with value 200
		brlo main02		;if it's less, higher digits are not incerasing
		subi R20,200	;subtract 200 from "twohundredths" unit
		inc R21			;add one second

		cpi R21,60		;compare with value 60
		brlo main02		;if it's less, higher digits are not incerasing
		subi R21,60		;subtract 60 seconds
		inc R22			;add one minute

		cpi R22,60		;compare with value 60
		brlo main02		;if it's less, higher digits are not incerasing
		subi R22,60		;subtract 60 minutes
		inc R23			;add one hour

		cpi R23,24		;compare with value 24
		brlo main02		;if it's less, higher digits are not incerasing
		subi R23,24		;subtract 24 hours
		adiw R24,1		;add one day (as unsigned int16)


main02:	
		rcall timetobuf	;calculate the time buffer
		rjmp main01


main03:							;start of reading
		wdr						;watchdog reset
		mov OldResult,NewResult	;will overwrite oldresult
		ldi R16,20				;here we will send a pulse as a request to answer
		rcall send1				;start bit
		ldi R16,16
		rcall send0

		ldi R16,16
		rcall send1
		ldi R16,20
		rcall send0				;we just wait here to make sure the signal is off

		rjmp capture
;		rjmp captureOK_Debug1




;local variables
.def i=R16

.def OldPINB=R15
.def TempHalfBit=R30

;return values
.def ResultByte=R29
.def HalfBitCounter=R28

;***************************************************************************
;* 
;* functions insertbit and capture
;*
;* program, which captures and decodes the received signal
;* registers for our usage here:
;* i, OldPINB, TempHalfBit (2 high registers, 1 low register) (R0,R31,R30)
;*
;* input values: nothing
;* return values:
;* HalfBitCounter - if the 7th bit is set, there is an error
;* ResultByte - the resulted byte, if everything is all right
;* (used 2 High registers, R28,R29)
;***************************************************************************


insertbit:						;inserts a particular bit
		lsl TempHalfBit			;shift TempHalfBit by one bit (there is a previous half-bit)
		sbrs OldPINB,7			;skip the next instruction, if the bit is set
		inc TempHalfBit			;if the bit is zero (LED on), increment one
		inc HalfBitCounter		;increment counter
		sbrc HalfBitCounter,0	;skip the next instruction, if the number is even (2,4,6,...)
		ret						;if odd (1,3,5,...) then nothing
		cpi TempHalfBit,1		;if value is 1
		breq insertbit1			;then jump to insertbit1
		cpi TempHalfBit,2		;if value is 2
		brne insertbit2			;if it's not 1 or 2, that's an error, jump to insertbit2
insertbit1:
		lsl ResultByte			;make space for a next bit
		sbrs TempHalfBit,0		;skip incrementing, if the bit 0 (lsb) is set
		inc ResultByte			;combination of 10 -> makes a single bit
		clr TempHalfBit			;reset register for half bits
		ret

insertbit2:
		pop OldPINB				
		rjmp capture03			

capture:
		clr ResultByte			;reset the register, where we will have the resulting 8 bits
		clr HalfBitCounter		;reset counter for half bits
		clr TempHalfBit			;reset space where we will put the half bits

		ldi i,3
		out TCCR0,i				;set timer to CLK/64, which is 17.361 us
								;for 36 pulses that's exactly 625 us
		clr i
		out TCNT0,i				;reset the counter (status) of timer
		
capture01a:
		sbis PINB,7				;we are waiting for a signal
		rjmp capture04			;if signal received, then jump
		in i,TCNT0				;read the timer counter (status)
		cpi i,32				;compare with value 23 (399 us)+1107=1506 us
		brlo capture01a			;if it is less, then repeat
		rjmp err				;here we have an input signal error
		

capture04:	
		cpi HalfBitCounter,12	;if the complete word (protocol) is ready
		breq capture05			;then continue on captureOK
		clr i
		out TCNT0,i				;reset the timer counter
		in OldPINB,PINB			;we will save the old value
		
capture01:	
;		rcall serial_send		;in a meantime we also send things to serial port ; not used anymore here
		in i,TCNT0				;read the timer counter
		cpi i,41				;compare with value 41 (about 40 pulses)
		brsh capture06			;if it's more or the same then jump
		cpi HalfBitCounter,11	;if we have the end of the frame (12th bit)
		brne capture01b
		cpi i,21				;compare with value 21 (about 20 pulses)
		brsh capture06			;if it's more or the same then jump
		
capture01b:
		in i,PINB				;here will will read the new value from the port
		eor i,OldPINB			;make exlusive or (XOR) with an old value (edge detection)
		andi i,128				;mask 7th bit
		breq capture01			;if zero, then repeat
		
capture02:
		in i,TCNT0				;read the timer status
		cpi i,9					;compare with 9 (about 8 pulses)
		brlo capture03			;if less, then end
		rcall insertbit			;insert into buffer one half-bit
		cpi i,25				;compare with value 25 (about 24 pulses)
		brlo capture04			;if less then jump to the beginning
		rcall insertbit			;insert another half-bit to buffer
		rjmp capture04			;detect next bit

capture03:
;		mov R16,HalfBitCounter
;		rcall sendpulse		
;
;		ori HalfBitCounter,128	;will set the highest bit (error indication) ; not used anymore
		rjmp err				;jump to error


capture06:						;if the interval is too long
		cpi HalfBitCounter,11	;test, if the counter is 11
		brne capture03			;if not, then decoding error
		sbrs OldPINB,7  		;skip the insruction, if OldPINB is zero
		rjmp capture03			;if oldPINB is not zero, then error...
		rcall insertbit			;insert also the last half-bit



;captureOK_Debug1:				;temporarily
;		ldi ResultByte,$3F

capture05:	
;								;and here we have the result in ResultByte
;								;continue into captureOK


captureOK:	
;		sbi PORTD,2
;		ldi R16,16
;		rcall wait_10us
;		cbi PORTD,2
;								;here we have the information
		andi ResultByte,$1C		;mask bits
		lsr ResultByte
		lsr ResultByte			;move to the right position
		mov NewResult,ResultByte
		inc NewResult			;increment by one
		cp OldResult,NewResult	;compare, if we have a change from the previous status
		breq captureOK1
		mov R26,NewResult		;adresa, where we will store the counter
		dec R26
		ldi R16,LED_Length		;set the length of ON status of the LED
		st X,R16
		ldi R16,'0'
		add R16,R26
		rcall sendbyte
		ldi R16,' '
		rcall sendbyte

		rcall sendtime			;will send the current time to the serial port

captureOK01:
		rcall serial_send
		rcall buf_free
		cpi R16,31
		brne captureOK01


captureOK1:
;		rcall serial_send
		ldi R16,4
		rcall wait_ms			;wait 4 ms
;		rcall serial_send
		ldi R16,16
		rcall wait_10us
;		rcall serial_send
		rjmp main01				;scanning again from the start


err:
		clr NewResult			;we don't have any code
	ldi R16,1
;	rcall send1					;will send an error signal ; not used anymore
	ldi R16,2
	rcall wait_ms
	rjmp main01					;jump to the start

;	sbi DDRB,5					;switch on the LED	;debugging code
;	ldi R16,50
;	rcall wait
;	cbi DDRB,5					;swithc off the LED
;	ldi R16,20
;	rcall wait

;	rjmp start






; vstupy:
; R16 - pocet ms na cakanie
; vystupy:
; meni registre: R16,R17,R18

wait_ms:				;vstup: R16
wait1:		ldi R17,5	;cakanie priblizne 1 ms
wait2:		clr R18
wait3:		dec R18
			brne wait3
			dec R17
			brne wait2
			dec R16
			brne wait1
			ret



; vstupy:
; R16 - pocet 10us na cakanie
; vystupy:
; meni registre: R16,R17

wait_10us:					;vstup: R16
waita1:		ldi R17,4		;cakanie priblizne 10 us
waita2:		dec R17
			brne waita2
			dec R16
			brne waita1
			ret

