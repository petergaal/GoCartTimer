
; This is a program for a mobile box, originally dated 31/01/2004

;.include "2313def.inc"
.include "tn12def.inc
;.include "D:\Program Files\Atmel\AVR Studio\Appnotes\tn12def.inc" 

	rjmp	RESET		;Reset handler
	rjmp    EXT_INT0	;IRQ0 handler
	rjmp	PIN_CHANGE	;Pin change handler
	rjmp	TIM0_OVF	;Timer0 overflow handler
	rjmp	EE_RDY		;EEPROM ready handler
	rjmp	ANA_COMP	;Analog comparator handler


EXT_INT0:
TIM0_OVF:
EE_RDY:
ANA_COMP:
PIN_CHANGE:
	reti         
 
						;make a signal which can be received by the IR sensor on other side
						;input: R31 - pulse count
send1:	sbi PORTB,2		;switch on the IR LED
		ldi R30,3
send1b:	dec R30
		brne send1b		;wait just exactly to make a 56 kHz signal for 1.2 MHz CPU clock
		cbi PORTB,2		;switch off the IR LED
		ldi R30,2
send1c:	dec R30
		brne send1c		;wait also during the switched off IR LED
		dec r31			;counting the pulses
		brne send1		;if still we have some, send another pulse
		ret				;otherwise we are finished, return back from the function



						;off signal
						;input: R31 - off pulse count
send0:	cbi PORTB,2		;switch off the IR LED
		dec r31
		breq send0d
send0b:	ldi r30,6
send0c:	dec r30
		brne send0c
		nop
		dec r31
		brne send0b
send0d:	ldi r30,6
send0e:	dec r30
		brne send0e
		ret


sendlog0:				;will send a sequence with logical 0 (non return to zero encoding)
		ldi R31,16		
		rcall send0
		ldi R31,16
		rcall send1
		ret

sendlog1:				;will send a sequence with logical 1
		ldi R31,16		
		rcall send1
		ldi R31,16
		rcall send0
		ret


RESET:
;		in R16,MCUSR
;		clr R31
;		out MCUSR,R31
;		andi R16,12

		wdr
		ldi R31,(1<<WDE)+2
		out WDTCR,R31	;enable watchdog to 64K cycles

EERead:	sbic EECR,EEWE	;if EEWE not clear
		rjmp EERead		;wait more
		clr R31
		out	EEAR,R31	;output address
		sbi	EECR,EERE	;set EEPROM Read strobe
						;This instruction takes 4 clock cycles since
						;it halts the CPU for two clock cycles
		in	R31,EEDR	;get data

		out OSCCAL,R31

EERead1:
		sbic EECR,EEWE	;if EEWE not clear
		rjmp EERead1	;wait more
		ldi R31,1
		out	EEAR,R31	
		sbi	EECR,EERE	;set EEPROM Read strobe
						;This instruction takes 4 clock cycles since
						;it halts the CPU for two clock cycles
		in	R0,EEDR		;here will be the mobile box code




		ldi R31,4+8+16
		out DDRB,R31	;set DDRB 2. pin to output
		ldi R31,1
		out PORTB,R31	;set PORTB pullup resistor to 0. output
						;and switch off red LED on PB5

		ldi R31,(1<<AINBG)
		out ACSR,R31

;		tst R16
;		brne start
		sbi DDRB,5
		clr R16
		rcall wait
		rcall wait
		cbi DDRB,5		;switch off output PB5
						;red LED switches on during the startup for about 0.5 seconds

		
start:
;		wdr
		clr R16
start1b:				;start of receiving a signal from static transmitter
		sbis PINB,0		;skip if the bit is zero (IR sensor receives)
;		wdr
		rjmp start1a    ;if not, start counting time
		dec R16
		brne start1b
;		dec R17
;		brne start1b
;		wdr
;		dec R18
;		brne start1b	;caka sa urcity cas na prijatie signalu
		rjmp start_sleep;if doesn't receive anything, CPU goes to sleep mode, just to have low power consumption on battery


start1a:
		clr R16
start1:	sbic PINB,0		;waiting for end of the signal from IR sensor, while counting time
		rjmp start2		;if signal went off, then jump
						;the pulse time should be about 357 us
		inc R16			;but we are waiting about 767 us
		brne start1		;loop until reaching timeout
		rjmp err		;here we have timeout

start_sleep:
		ldi R16,(1<<WDE)+(1<<WDTOE)+2
		out WDTCR,R16	;prepare for disabling watchdog
		ldi R16,(1<<WDTOE)
		out WDTCR,R16	;disable watchdog


		ldi R16,(1<<PCIF)
		out GIFR,R16	;enable pin change interrupt
		ldi R16,(1<<PCIE)
		out GIMSK,R16	;enable pin change interrupt
		ldi R16,(1<<ACD)
		out ACSR,R16
		ldi R16,(1<<SE)+(1<<SM)
		out MCUCR,R16	;enable sleep, in power down mode

;		sbis PINB,0		;last test, if I don't get a signal ; not necessary
;		rjmp start_sleep1
		sei				;enable interrupts
		sleep			;sleep procesor
		cli				;disable interrupts

start_sleep1:
		clr R16
		out GIMSK,R16	;disable pin change interrupty
		out MCUCR,R16	;disable sleep mode
		ldi R16,(1<<AINBG)
		out ACSR,R16
		wdr
		ldi R16,(1<<WDE)+2
		out WDTCR,R16	;enable watchdog to 64K cycles
		rjmp start


err:	
;		sbi DDRB,5		;switch on the red LED
;		ldi R16,50
;		rcall wait
;		cbi DDRB,5		;switch off the red LED
;		ldi R16,20
;		rcall wait

		rjmp start		;just try again to detect the start code from the start



start2:	cpi R16,59		;comparing with value 250 us
		brlo err		;if less, then error
		cpi R16,110		;comparing with value 464 us
		brsh err		;if more, then error
						;otherwise it's inside the tolerance, let's test it more

		clr R16
start3:	sbis PINB,0		;waiting for start of the signal from IR sensor, while counting time
		rjmp start4		;if started, then jump
st3c:	inc R16
		brne start3		;loop until reaching timeout
		rjmp err		;here we have timeout

start4:	cpi R16,42		;comparing with value 179 us
		brlo err		;if less, then error
		cpi R16,94		;comparing with value 393 us
		brsh err		;if more, then error


		clr R16
start5:	sbic PINB,0		;waiting for end of the signal from IR sensor, while counting time
		rjmp start6		;if signal went off, then jump
st5c:	inc R16
		brne start5		;loop until reaching timeout
		rjmp err		;here we have timeout

start6:	cpi R16,66		;comparing with value 277,77 us
		brlo err		;if less, then error
		cpi R16,146		;comparing with value 611,11 us
		brsh err		;if more, then error

		sbi DDRB,5		;switch on the signaling red LED
		ldi R31,16		;here we have received successfully the request from static box
		rcall send0		;and we will wait 16 pulses = 285 us

		mov R1,R0		;load the own mobile box code
		swap R1			;swap low and high 4 bits
		lsl R1			;shift left by one

						;We will send out data sequence: 1XXXB1 (X - code, B - battery status)
		rcall sendlog1	;start bit


		lsl R1			;bit 2 of the code (1st data bit)
		brcs data1a		;if set, then jump
		rcall sendlog0	;otherwise send logical 0
		rjmp data2
data1a:	rcall sendlog1	;send logical 1

data2:	lsl R1			;bit 1 of the code (2nd data bit)
		brcs data2a		;if set, then jump
		rcall sendlog0	;otherwise send logical 0
		rjmp data3
data2a:	rcall sendlog1

data3:	lsl R1			;bit 0 of the code (3rd data bit)
		brcs data3a		;if set, then jump
		rcall sendlog0	;otherwise send logical 0
		rjmp bat1
data3a:	rcall sendlog1	;send logical 1

bat1:	sbis ACSR,5		;check analog comparator output
		rjmp start7		;jump, if battery is not low
		rcall sendlog1	;battery bit (logical 1)
		rjmp start8

start7:	rcall sendlog0	;battery bit (logical 0)


start8:	ldi R31,16		;stop bit 
		rcall send1		
		ldi R31,16
		rcall send0


		ldi R16,1		;wait about 1 ms
;		wdr
		rcall wait
;		wdr
		cbi DDRB,5		;switch off the red signaling LED
;		ldi R16,1
;		rcall wait

;		sbi DDRB,5		;blink second time
;		ldi R16,50
;		rcall wait
;		cbi DDRB,5		;swtich off red LED
;		ldi R16,50
;		rcall wait


		rjmp start
	

wait:					;input: R16
wait1:	ldi R31,2		;wait about 1 ms
wait2:	ldi R30,199
wait3:	dec R30
		brne wait3
		dec R31
		brne wait2
		wdr
		dec R16
		brne wait1
		ret

