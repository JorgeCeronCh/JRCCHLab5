/*	
    Archivo:		Lab5main.S
    Dispositivo:	PIC16F887
    Autor:		Jorge Cerón 20288
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		Contador binario de 8 bits incremento/decremento con interrupciones
			
    Hardware:		LEDs en puerto A y 2 contadores de 7 segmentos en puerto C

    Creado:			23/02/22
    Última modificación:	23/02/22	
*/

PROCESSOR 16F887
#include <xc.inc>

; configuracion 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscillador Interno sin salidas
  CONFIG  WDTE = OFF            // WDT (Watchdog Timer Enable bit) disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = OFF            // PWRT enabled (Power-up Timer Enable bit) (espera de 72 ms al iniciar)
  CONFIG  MCLRE = OFF           // El pin de MCL se utiliza como I/O
  CONFIG  CP = OFF              // Sin proteccion de codigo
  CONFIG  CPD = OFF             // Sin proteccion de datos
  
  CONFIG  BOREN = OFF           // Sin reinicio cunado el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF              // programación en bajo voltaje permitida

; configuracion  2
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivada
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V = 2.1V)
  
UP	EQU 0			// Equivalencia de UP=0
DOWN	EQU 1			// Equivalencia de DOWN=1

PSECT udata_bank0
    CONT1:	    DS 1
    BANDERADISP:    DS 1
    NIBBLES:	    DS 2
    DISPLAY:	    DS 2

;----------------MACROS--------------- Macro para reiniciar el valor del Timer0
RESETTIMER0 MACRO
    BANKSEL TMR0	// Direccionamiento al banco 00
    MOVLW   217		// Cargar literal en el registro W
    MOVWF   TMR0	// Configuración completa para que tenga 50ms de retardo
    BCF	    T0IF	// Se limpia la bandera de interrupción
    
    ENDM
; Status para interrupciones
PSECT udata_shr			// Variables globales en memoria compartida
    WTEMP:	    DS 1	// 1 byte
    STATUSTEMP:	    DS 1	// 1 byte
     
PSECT resVect, class=CODE, abs, delta=2	
;----------------vector reset----------------
ORG 00h				// Posición 0000h para el reset
resVect:
    PAGESEL	main		//Cambio de página
    GOTO	main

PSECT intVect, class=CODE, abs, delta=2 
;----------------vector interrupcion---------------
ORG 04h				// Posición 0004h para las interrupciones
PUSH:				// PC a pila
    MOVWF   WTEMP		// Se mueve W a la variable WTEMP
    SWAPF   STATUS, W		// Swap de nibbles del status y se almacena en W
    MOVWF   STATUSTEMP		// Se mueve W a la variable STATUSTEMP
ISR:				// Rutina de interrupción
    
    BTFSC   T0IF		// Analiza la bandera de cambio del TMR0 si esta encendida (si no lo está salta una linea)
    CALL    INT_TMR0		// Se llama la rutina de interrupción del TMR0

    BTFSC   RBIF		// Analiza la bandera de cambio del PORTB si esta encendida (si no lo está salta una linea)
    CALL    INTERRUPIOCB	// Se llama la rutina de interrupción del puerto B

    BANKSEL PORTA
POP:				// Intruccion movida de la pila al PC
    SWAPF   STATUSTEMP, W	// Swap de nibbles de la variable STATUSTEMP y se almacena en W
    MOVWF   STATUS		// Se mueve W a status
    SWAPF   WTEMP, F		// Swap de nibbles de la variable WTEMP y se almacena en WTEMP 
    SWAPF   WTEMP, W		// Swap de nibbles de la variable WTEMP y se almacena en w
    
    RETFIE
    
INT_TMR0:
    RESETTIMER0			// Se reinicia TMR0 para 50ms
    CALL    MOSTRAR_VALOR	// Se muestra valor en hexadecimal en los displays
    
    RETURN

MOSTRAR_VALOR:
    BCF	    PORTD, 0		// Se limpia display de nibble alto
    BCF	    PORTD, 1		// Se limpia display de nibble bajo
    BTFSC   BANDERADISP, 0	// Se verifica bandera
    GOTO    DISPLAY_1		  

DISPLAY_0:			
    MOVF    DISPLAY, W		// Se mueve display a W
    MOVWF   PORTC		// Se mueve valor de tabla a PORTC
    BSF	    PORTD, 1		// Se enciende display de nibble bajo
    BSF	    BANDERADISP, 0	// Cambio de bandera para cambiar el otro display en la siguiente interrupción
    
    RETURN

DISPLAY_1:
    MOVF    DISPLAY+1, W	// Se mueve display+1 a W
    MOVWF   PORTC		// Se mueve valor de tabla a PORTC
    BSF	    PORTD, 0		// Se enciende display de nibble alto
    BCF	    BANDERADISP, 0	// Cambio de bandera para cambiar el otro display en la siguiente interrupción
    
    RETURN
    
INTERRUPIOCB:
    BANKSEL PORTA
    BTFSS   PORTB, UP		// Analiza RB0 si no esta presionado (si está presionado salta una linea)
    CALL    INCREMENTO		
    BTFSS   PORTB, DOWN		// Analiza RB1 si no esta presionado (si está presionado salta una linea)
    CALL    DECREMENTO
    BCF	    RBIF		// Se limpia la bandera de cambio de estado del PORTB
    
    RETURN
    
INCREMENTO:
    INCF    PORTA		// Incremento en 1 puerto A
    INCF    CONT1
    
    RETURN

DECREMENTO:
    DECF    PORTA		// Disminución en 1 puerto A
    DECF    CONT1
    
    RETURN
PSECT code, abs, delta=2   
;----------------configuracion----------------
ORG 100h
main:
    CALL    CONFIGIO	    // Se llama la rutina configuración de entradas/salidas
    CALL    CONFIGRELOJ	    // Se llama la rutina configuración del reloj
    CALL    CONFIGTIMER0    // Se llama la rutina configuración del TMR0
    CALL    CONFIGINTERRUP  // Se llama la rutina configuración de interrupciones
    CALL    CONFIIOCB	    // Se llama la rutina configuración de interrupcion en PORTB
    BANKSEL PORTA
    
loop:
    CALL    OBTENER_NIBBLES // Se llama la rutina para guardar nibble alto y bajo de CONT1
    CALL    SET_DISPLAY	    // Se llama la rutina para guardar los valores a enviar en PORTC en hex
    GOTO    loop	    // Regresa a revisar	    
    
CONFIGRELOJ:
    BANKSEL OSCCON	// Direccionamiento al banco 01
    BSF OSCCON, 0	// SCS en 1, se configura a reloj interno
    BSF OSCCON, 6	// bit 6 en 1
    BSF OSCCON, 5	// bit 5 en 1
    BCF OSCCON, 4	// bit 4 en 0
    // Frecuencia interna del oscilador configurada a 4MHz
    RETURN   
    
CONFIGTIMER0:
    BANKSEL OPTION_REG	// Direccionamiento al banco 01
    BCF OPTION_REG, 5	// TMR0 como temporizador
    BCF OPTION_REG, 3	// Prescaler a TMR0
    BSF OPTION_REG, 2	// bit 2 en 1
    BSF	OPTION_REG, 1	// bit 1 en 1
    BSF	OPTION_REG, 0	// bit 0 en 1
    // Prescaler en 256
    // Sabiendo que N = 256 - (T*Fosc)/(4*Ps) -> 256-(0.01*4*10^6)/(4*256) = 216.93 (217 aprox)
    RESETTIMER0
    
    RETURN
    
CONFIGIO:
    BANKSEL ANSEL	// Direccionar al banco 11
    CLRF    ANSEL	// I/O digitales
    CLRF    ANSELH	// I/O digitales
    
    BANKSEL TRISA	// Direccionar al banco 01
    BSF	    TRISB, UP	// RB0 como entrada
    BSF	    TRISB, DOWN	// RB1 como entrada
    BCF	    TRISD, UP	// RD0 como salida
    BCF	    TRISD, DOWN	// RD1 como salida
    CLRF    TRISA	// PORTA como salida
    CLRF    TRISC	// PORTC como salida
    
    BCF	    OPTION_REG, 7   // RBPU habilita las resistencias pull-up 
    BSF	    WPUB, UP	    // Habilita el registro de pull-up en RB0 
    BSF	    WPUB, DOWN	    // Habilita el registro de pull-up en RB1
    
    BANKSEL PORTA	// Direccionar al banco 00
    CLRF    PORTA	// Se limpia PORTA
    CLRF    PORTB	// Se limpia PORTB
    CLRF    PORTC	// Se limpia PORTC
    CLRF    PORTD	// Se limpia PORTD
    
    CLRF    CONT1	// Se limpia variable CONT1
    CLRF    BANDERADISP	// Se limpia variable BANDERADISP
    CLRF    NIBBLES	// Se limpia variable CONT1
    CLRF    DISPLAY	// Se limpia variable BANDERADISP

    RETURN
    
CONFIGINTERRUP:
    BANKSEL INTCON
    BSF	    GIE		    // Habilita interrupciones globales
    BSF	    RBIE	    // Habilita interrupciones de cambio de estado del PORTB
    BCF	    RBIF	    // Se limpia la banderda de cambio del puerto B
    
    BSF	    T0IE	    // Habilita interrupción TMR0
    BCF	    T0IF	    // Se limpia de una vez la bandera de TMR0
    
    RETURN
    
CONFIIOCB:		    // Interrupt on-change PORTB register
    BANKSEL TRISA
    BSF	    IOCB, UP	    // Interrupción control de cambio en el valor de B
    BSF	    IOCB, DOWN	    // Interrupción control de cambio en el valor de B
    
    BANKSEL PORTA
    MOVF    PORTB, W	    // Termina la condición de mismatch, compara con W
    BCF	    RBIF	    // Se limpia la bandera de cambio de PORTB
    
    RETURN
    
OBTENER_NIBBLES:			
    // Obtención de nibble bajo
    MOVLW   0x0F		// Se mueve valor 0000 1111 
    ANDWF   CONT1, W		// Solo se dejan pasar los primero 4 bits con AND
    MOVWF   NIBBLES		// Pasan los 4 bits anteriores a una nueva variable	
    // Obtención de nibble alto
    MOVLW   0xF0		// Se mueve valor 1111 0000
    ANDWF   CONT1, W		// Solo se dejan pasar los últimos 4 bits con AND
    MOVWF   NIBBLES+1		// Pasan los 4 bits anteriores aL 2do byte de la variable
    SWAPF   NIBBLES+1, F	// Se hace un swap de nibbles para que este, almacenado en los últimos 4 bits, pase a los primeros 4 bits
    RETURN
    
SET_DISPLAY:
    MOVF    NIBBLES, W		// Se mueve nibble bajo a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY		// Se guarda en nueva variable display
    
    MOVF    NIBBLES+1, W	// Se mueve nibble alto a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY+1		// Se guarda en variable display en el 2do byte
    RETURN

ORG 200h
TABLA:
    CLRF    PCLATH	// Se limpia el registro PCLATH
    BSF	    PCLATH, 1	
    ANDLW   0x0F	// Solo deja pasar valores menores a 16
    ADDWF   PCL		// Se añade al PC el caracter en ASCII del contador
    RETLW   00111111B	// Return que devuelve una literal a la vez 0 en el contador de 7 segmentos
    RETLW   00000110B	// Return que devuelve una literal a la vez 1 en el contador de 7 segmentos
    RETLW   01011011B	// Return que devuelve una literal a la vez 2 en el contador de 7 segmentos
    RETLW   01001111B	// Return que devuelve una literal a la vez 3 en el contador de 7 segmentos
    RETLW   01100110B	// Return que devuelve una literal a la vez 4 en el contador de 7 segmentos
    RETLW   01101101B	// Return que devuelve una literal a la vez 5 en el contador de 7 segmentos
    RETLW   01111101B	// Return que devuelve una literal a la vez 6 en el contador de 7 segmentos
    RETLW   00000111B	// Return que devuelve una literal a la vez 7 en el contador de 7 segmentos
    RETLW   01111111B	// Return que devuelve una literal a la vez 8 en el contador de 7 segmentos
    RETLW   01101111B	// Return que devuelve una literal a la vez 9 en el contador de 7 segmentos
    RETLW   01110111B	// Return que devuelve una literal a la vez A en el contador de 7 segmentos
    RETLW   01111100B	// Return que devuelve una literal a la vez b en el contador de 7 segmentos
    RETLW   00111001B	// Return que devuelve una literal a la vez C en el contador de 7 segmentos
    RETLW   01011110B	// Return que devuelve una literal a la vez d en el contador de 7 segmentos
    RETLW   01111001B	// Return que devuelve una literal a la vez E en el contador de 7 segmentos
    RETLW   01110001B	// Return que devuelve una literal a la vez F en el contador de 7 segmentos
END
