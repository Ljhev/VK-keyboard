 list		p=16f628a, b=4
 #include	<p16f628a.inc>	


 errorlevel	-302, -307		

 __config	H'3F10'

#DEFINE kdata	PORTB, 7
#DEFINE kclk	PORTB, 6
#DEFINE GrnLED	PORTA, 7
#DEFINE RedLED	PORTA, 6

#DEFINE TMR1Div	.125		
#DEFINE TMR2Div	.175		

 CBLOCK		0x70	
	w_temp			
	status_temp		
	pclath_temp
 ENDC

 CBLOCK		0x20    
 _ScanCode
 _BitCount
 _parity

 delay1
 delay2
 phrase_count
 phrase_currcnt
 out_char
 key_row
 key_col
 key_tmp
 key_code		
 out_mode
 space_mode
 TMR2CntLo

 ReadyCntLo
 ReadyCntHi
 myFlags		
 errcnt
 ENDC


 ORG 0x000					
	movlw	0x07
	movwf	CMCON			
    goto	start			

 ORG		0x004			
	movwf	w_temp			
	movf	STATUS, W		
	movwf	status_temp

	clrf	STATUS          



	btfsc	PIR1, TMR2IF
	goto	TMR2_int
	btfsc	PIR1, TMR1IF
	goto	TMR1_int
	goto	exit_int

TMR1_int
	bcf		T1CON, TMR1ON	
	movlw	b'00001000'		
	xorwf	PORTB, F
	movlw	0xFF			
	movwf	TMR1H
	movlw	TMR1Div			
	movwf	TMR1L
	bcf		PIR1, TMR1IF
	bsf		T1CON, TMR1ON	
	goto	exit_int

TMR2_int
	bcf		T2CON, TMR2ON	
	bcf		PIR1, TMR2IF

	movlw	b'00001000'		
	xorwf	PORTB, F

	incf	TMR2CntLo, F



	btfss	TMR2CntLo, 6
	goto	continue_TMR2int

	bcf		T2CON, TMR2ON	
	bsf		STATUS, RP0		
	bcf		PIE1, TMR2IE	
	bcf		STATUS, RP0		
	clrf	INTCON
	bcf		myFlags, 0		
	bcf		PORTB, 3		
	goto	exit_int

continue_TMR2int
	movlw	TMR2Div
	movwf	TMR2
	bsf		T2CON, TMR2ON	

exit_int

	movf	status_temp, W
	movwf	STATUS
    swapf	w_temp, F
    swapf	w_temp, W
	retfie		



start

	banksel	0				
	clrf	INTCON			
	clrf	PORTA

	movlw	b'11010000'		
	movwf	PORTB

	bsf		STATUS, RP0		
	bsf		PCON, OSCF		
	movlw	b'00111111'
	movwf	TRISA			
	movlw	b'11000000'
	movwf	TRISB			

	
	movlw	b'10000010'
	movwf	OPTION_REG
	bcf		STATUS, RP0		

	clrf	myFlags

	movlw	0x03
	call	read_eeprom
	movwf	out_mode
	movlw	.3				
	subwf	out_mode, W
	btfsc	STATUS, C
	clrf	out_mode

	call	indic_out_mode
	clrf	key_row
	movlw	0x01
	call	read_eeprom
	movwf	space_mode
repeat_cycle


	movf	PORTB, W
	andlw	b'11111000'
	iorwf	key_row, W
	movwf	PORTB
	nop
	nop
	movlw	b'11100000'
	iorwf	PORTA, W
	movwf	key_tmp
	incf	key_tmp, W		
	btfss	STATUS, Z
	goto	check_keypress
next_row_check
	incf	key_row, F		
	btfsc	key_row, 3		
	clrf	key_row

	goto	repeat_cycle

check_keypress
	call	delay_key_drebezg	
	movlw	b'11100000'
	iorwf	PORTA, W
	subwf	key_tmp, W
	btfss	STATUS, Z
	goto	next_row_check	
	btfsc	myFlags, 0		
	goto	no_sound_on
	bsf		myFlags, 0
	clrf	TMR2CntLo		

	movlw	b'00001100'
	movwf	T2CON
	movlw	TMR2Div
	movwf	TMR2
	bsf		STATUS, RP0		
	movlw	0xFF
	movwf	PR2
	bsf		PIE1, TMR2IE	
	bcf		STATUS, RP0		
	movlw	b'11000000'
	movwf	INTCON

no_sound_on
	clrf	key_code
	btfss	key_tmp, 0
	goto	col_1
	btfss	key_tmp, 1
	goto	col_2
	btfss	key_tmp, 2
	goto	col_3
	btfss	key_tmp, 3
	goto	col_4
	btfss	key_tmp, 4
	goto	col_5
	goto	repeat_cycle	
col_1
	movlw	b'00000000'
	goto	make_keycode
col_2
	movlw	b'00001000'
	goto	make_keycode
col_3
	movlw	b'00010000'
	goto	make_keycode
col_4
	movlw	b'00011000'
	goto	make_keycode
col_5
	movlw	b'00100000'

make_keycode
	iorwf	key_row, W
	movwf	key_code

	movlw	.40
	subwf	key_code, W
	btfsc	STATUS, C
	goto	next_row_check	

	movf	key_code, W		
	btfss	STATUS, Z
	goto	keyboard_out_phrase
	call	change_out_mode
	goto	wait_key_up

keyboard_out_phrase
	call	out_phrase_kbd

wait_key_up					
	movlw	b'11100000'
	iorwf	PORTA, W
	movwf	key_tmp
	incf	key_tmp, W		
	btfss	STATUS, Z
	goto	wait_key_up

   	goto	next_row_check



out_phrase_kbd
	bsf		PORTB, 5			

	clrf	ReadyCntLo
	clrf	ReadyCntHi
wait_keyboard_ready				
	movlw	.14					
	movwf	delay1

	incf	ReadyCntLo, F		
	btfsc	STATUS, Z
	incf	ReadyCntHi, F
	btfss	ReadyCntHi, 5		
	goto	d_c_waitk
	call	kbd_send_error		
	call	indic_out_mode		
	return						

d_c_waitk
	btfss	kclk				
	goto	wait_keyboard_ready
	btfss	kdata				
	goto	wait_keyboard_ready
	decfsz	delay1, f
	goto	d_c_waitk

	bcf		PORTB, 4			
	bcf		PORTB, 5			
	bsf		STATUS, RP0			
	clrf	TRISB			
	bcf		STATUS, RP0		
	bsf		kdata
	bsf		kclk
	bsf		PORTB, 5			

	clrf	phrase_count		
	clrf	phrase_currcnt		

	btfss	space_mode, 0		
	goto	next_charout1
	movlw	0x29				
	call	kbd_sendbyte
	call	delay_key_out
	movlw	0xF0				
	call	kbd_sendbyte
	call	delay_F0
	movlw	0x29				
	call	kbd_sendbyte
	call	delay_key_out

next_charout1
	movlw	HIGH $
	movwf	PCLATH
	decf	key_code, W			
	addwf	PCL, F
	goto	phrase01
	goto	phrase02
	goto	phrase03
	goto	phrase08
	goto	phrase17
	goto	phrase18
	goto	phrase19
	
	
phrase01
	call	get_phrase01_cur_char
	goto	next_op
phrase02
	call	get_phrase02_cur_char
	goto	next_op	
phrase03
	call	get_phrase03_cur_char
	goto	next_op	

phrase08
	call	get_phrase08_cur_char
	goto	next_op	

phrase16
	call	get_phrase16_cur_char
	goto	next_op
phrase17
	call	get_phrase17_cur_char
	goto	next_op	
phrase18
	call	get_phrase18_cur_char
	goto	next_op	
phrase19
	call	get_phrase19_cur_char
	goto	next_op	


next_op
	movwf	out_char
	movf	phrase_currcnt, W	
	btfsc	STATUS, Z
	goto	no_out_curchar

	movlw	.1					
	subwf	phrase_currcnt, W
	btfss	STATUS, Z
	goto	no_out_shift1
	movf	out_mode, W			
	btfsc	STATUS, Z
	goto	no_out_shift1
	movlw	0x12				
	call	kbd_sendbyte
	call	delay_key_out

no_out_shift1
	movlw	.2					
	subwf	phrase_currcnt, W
	btfss	STATUS, Z
	goto	no_out_shift2
	movlw	.1					
	subwf	out_mode, W
	btfss	STATUS, Z
	goto	no_out_shift2
	
	movlw	0xF0
	call	kbd_sendbyte
	call	delay_F0
	movlw	0x12				
	call	kbd_sendbyte
	call	delay_key_out


no_out_shift2
	movf	out_char, W
	call	kbd_sendbyte
 
	call	delay_key_out
	
	movlw	0xF0
	call	kbd_sendbyte
	call	delay_F0
	movf	out_char, W
	call	kbd_sendbyte

	call	delay_key_out


	goto	next_curchar

no_out_curchar
	movf	out_char, W
	movwf	phrase_count

next_curchar
	incf	phrase_currcnt, F
	movf	phrase_count, W
	subwf	phrase_currcnt, W
	btfss	STATUS, C
	goto	next_charout1

	movlw	.2					
	subwf	out_mode, W
	btfss	STATUS, Z
	goto	no_out_shift3
	
	movlw	0xF0
	call	kbd_sendbyte
	call	delay_F0
	movlw	0x12				
	call	kbd_sendbyte
	call	delay_key_out

no_out_shift3
	btfss	space_mode, 1		
	goto	end_kbd_send_phrase
	movlw	0x29				
	call	kbd_sendbyte
	call	delay_key_out
	movlw	0xF0				
	call	kbd_sendbyte
	call	delay_F0
	movlw	0x29				
	call	kbd_sendbyte
	call	delay_key_out

end_kbd_send_phrase
	bcf		PORTB, 5			
	bsf		PORTB, 4			

	bsf		STATUS, RP0			
	movlw	b'11000000'
	movwf	TRISB				
	bcf		STATUS, RP0			
	call	delay_F0
	return


kbd_sendbyte
	movwf	_ScanCode		
	movlw	0x08
	movwf	_BitCount		
	clrf	_parity
	bsf		kdata
	bsf		kclk	

	bcf		kdata			
	call	delay_kbclk
	bcf		kclk
	call	delay_kbclk
	bsf		kclk

SendNextBit
	bcf     STATUS, C
	rrf     _ScanCode, F

	btfsc   STATUS, C
	goto	_set_kdata

_clear_kdata
	bcf		kdata
	goto	_ready_send

_set_kdata
	bsf		kdata
	incf	_parity, F
	
_ready_send
	call	delay_kbclk
	bcf		kclk
	call	delay_kbclk
	bsf		kclk

	decfsz	_BitCount, 1	
	goto	SendNextBit

	incf	_parity, F		
	btfsc	_parity, 0
	goto	_set_kdata_par

	bcf		kdata
	goto	_par_clk

_set_kdata_par
	bsf		kdata

_par_clk
	call	delay_kbclk
	bcf		kclk
	call	delay_kbclk
	bsf 	kclk
	nop
	nop
	bsf		kdata			
	call	delay_kbclk
	bcf		kclk
	call	delay_kbclk
	bsf		kclk
	return


change_out_mode
	incf	out_mode, F
	movlw	.3
	subwf	out_mode, W
	btfsc	STATUS, C
	clrf	out_mode
	goto	indic_out_mode
	return

indic_out_mode
	bsf		GrnLED			
	bsf		RedLED
	btfsc	out_mode, 0
	bcf		GrnLED
	btfsc	out_mode, 1
	bcf		RedLED
	return

delay_kbclk					
	movlw	.7
	movwf	delay1
d_c_kbclk
	nop
	decfsz	delay1, f
	goto	d_c_kbclk
	return

delay_F0					
	movlw	.04
	movwf	delay2
d_c_F0_1
	movlw	.200
	movwf	delay1
d_c_F0_2
	nop
	decfsz	delay1, f
	goto	d_c_F0_2
	decfsz	delay2, f
	goto	d_c_F0_1
	return

delay_key_out				
	movlw	0Ah
	movwf	delay2
d_c_2
	movlw	0F0h
	movwf	delay1
d_c_1
	nop
	decfsz	delay1, f
	goto	d_c_1
	decfsz	delay2, f
	goto	d_c_2
	return

delay_key_drebezg
	movlw	.8
	movwf	delay2
k_d_2
	movlw	0FFh
	movwf	delay1
k_d_1
	nop
	decfsz	delay1, f
	goto	k_d_1
	decfsz	delay2, f
	goto	k_d_2
	return

read_eeprom					
	bsf		STATUS, RP0		
	movwf	EEADR
	bsf		EECON1, RD		
	movf	EEDATA, W		
	bcf		STATUS, RP0		
	return

kbd_send_error
	btfss	myFlags, 0		
	goto	start_err_snd
	bcf		T2CON, TMR2ON	
	bsf		STATUS, RP0		
	bcf		PIE1, TMR2IE	
	bcf		STATUS, RP0		
start_err_snd
	bsf		myFlags, 0		
	movlw	0xFF			
	movwf	TMR1H
	movlw	TMR1Div			
	movwf	TMR1L
	movlw	b'11000000'
	movwf	INTCON
	movlw	b'00100101'		
	movwf	T1CON
	bsf		STATUS, RP0		
	bsf		PIE1, TMR1IE	
	bcf		STATUS, RP0		

	movlw	.3				
	movwf	errcnt
err_rep
	bsf		GrnLED			
	bcf		RedLED
	call	delay_key_out
	call	delay_key_out
	call	delay_key_out
	bsf		RedLED
	bcf		GrnLED
	call	delay_key_out
	call	delay_key_out
	call	delay_key_out
	decfsz	errcnt, f
	goto	err_rep

	bcf		T1CON, TMR1ON	
	bsf		STATUS, RP0		
	bcf		PIE1, TMR1IE	
	bcf		STATUS, RP0		
	clrf	INTCON
	bcf		PORTB, 3		
	bcf		myFlags, 0		
	return


 FILL (goto start), (0x0400 - $)

;;;;;;;;;;;;;
 ORG 0x400
;;;;;;;;;;;;;
get_phrase01_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.3		;кол-во символов + 1
 retlw	0x14	;ctrl
 retlw	0x21	;c


get_phrase02_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.3		;кол-во символов + 1
 retlw	0x14	;ctrl
 retlw	0x1C	;a
 

get_phrase03_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.3		;кол-во символов + 1
 retlw	0x11	;alt
 retlw	0x04	;f4
 




get_phrase08_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.7		;кол-во символов + 1
 retlw	0x54	;х
 retlw	0x3B	;о
 retlw	0x33	;р
 retlw	0x3B	;о
 retlw	0x43	;ш
 retlw	0x3B	;о
 
 FILL (goto start), (0x0500 - $)

;;;;;;;;;;;;;
 ORG 0x500
;;;;;;;;;;;;;

get_phrase16_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.4		;кол-во символов + 1
 retlw	0x14	;ctrl
 retlw	0x12	;shift
 retlw	0x76	;esc
 


get_phrase17_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.3		;кол-во символов + 1
 retlw	0x14	;ctrl
 retlw	0x2A	;v
 

get_phrase18_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.3		;кол-во символов + 1
 retlw	0x14	;ctrl
 retlw	0x4D	;p

get_phrase19_cur_char
 movlw	HIGH $
 movwf	PCLATH
 movf	phrase_currcnt,W
 addwf	PCL, F
 retlw	.7		;кол-во символов + 1
 retlw	0x34	;п
 retlw	0x33	;р
 retlw	0x32	;и
 retlw	0x23	;в
 retlw	0x2C	;е
 retlw	0x31	;т

 FILL (goto start), (0x0600 - $)




; EEPROM

 ORG 0x2100		

 DE	0x00
 DE	b'00000000'	
				
 DE	0x00
 DE	0x00		
				
				
				

 DE 0,0,0,0,"Vk Keyboard",0,0,0,0,0,0
 END 
