;based on the code by VINOD.S <vinodstanur@gmail.com> <http://blog.vinu.co.in>
;
;-->atmega328p
;author Juan Diego Torres Morales
;author Pablo Merizalde Maya
;AVR atmega328p

;codigo super hipermega comentado
.include "./m328Pdef.inc"
.cseg
;DEFINICIONES--------------------------------------------------------------------;
	.equ	pepe			= (SRAM_START + 3)
	.equ	SemaStart 		= (SRAM_START + 4)
	.equ	tareasTotales 	= 4
	.equ	indexTareas		= (RAMEND)
	.equ 	tareasBackUp	= (RAMEND - 4)		;redireccion para las tareas
	.equ	t1Stack			= (RAMEND - 50)		;SP tarea1
	.equ	t2Stack			= (RAMEND - 612)	;SP tarea2
	.equ	t3Stack			= (RAMEND - 1176)	;SP tarea3
	.equ	t4Stack			= (RAMEND - 1739)	;SP tarea4
;--------------------------------------------------------------------------------;


.cseg

;interrupciones

;reset
.org 0x0000
	jmp Inicializacion


;boton
.org INT0addr
	rjmp BotonY

;timer
.org OVF0addr
	jmp CambioContexto



Inicializacion:

	;todo lo del timer
	;arranco TCNT0 en 0
	clr r16
	out TCNT0, r16

	;configuro el TCCR0B con un prescaler de 1024
	ldi r17, 0x05
	out TCCR0B, r17

	;configuro el TIMSK0, habilita el timer
	ldi r19, 0x01
	sts TIMSK0, r19

	;todo lo del boton
	.def temp = r18
	ser temp
	out DDRC, temp
	ldi temp, (1 << ISC11) | (1 << ISC01)
	sts EICRA, temp
	in temp, EIMSK 
	ori temp, (1<<INT0) | (1<<INT1)
	out EIMSK, temp
	sei

	;guardo el numero de tareas
	ldi r16, 4
	sts pepe, r16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CONFIGURACION INICIAL DE tareasBackUp					 ;
;se llena con el poninter a cada tarea                   ;
;uso el r16 como un registro auxiliar 					 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;inicializo el registro Z
	ldi ZH, high(tareasBackUp)
	ldi ZL, low(tareasBackUp)

;-----------BackUp tarea1:---------------------------------
	;como va a ser la tarea inicial pongo el StackPointer Low y
	;el StackPointerHigh a comenzar aqui (SPL y SPH)

	ldi r16, high(t1Stack)
	st z, r16
	;para el StackPointer High SPH
	out SPH, r16
	ldi r16, low(t1Stack)
	st -z, r16
	;para el StackPointer Low SPL
	out SPL, r16
;>>nota: el -z es que predecrementa a lo que este apuntando el
;registro z tambien se puede para el x y para el y al igual que
;post incrementar z+

;-----------BackUp tarea2:---------------------------------
	;agrego los 35 espacios que se deben de reservar para SREG
	;GPR y PC
	ldi r16, high(t2Stack - 33)
	st -z, r16
	ldi r16, low(t2Stack - 33)
	st -z, r16

;-----------BackUp tarea3:---------------------------------
	ldi r16, high(t3Stack - 33)
	st -z, r16
	ldi r16, low(t3Stack - 33)
	st -z, r16

;-----------BackUp tarea4:---------------------------------
	ldi r16, high(t4Stack - 33)
	st -z, r16
	ldi r16, low(t4Stack - 33)
	st -z, r16

;-----------------------------------------------------------
	;arranco el index de las tareas
	clr r16
	sts indexTareas, r16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CONFIGURACION INICIAL DEL PROGRAM COUNTER				 ;
;se cuadra el pc para cuando se valla a saltar con reti  ;
;se hace desde la tarea2 hasta la tarea4, ya que la      ;
;tarea1 se arranca por predeterminado 					 ;
;se llaman a las tareas (labels)						 ;
;uso el r16 como registro auxiliar						 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;-----------PC tarea2:--------------------------------------
	;cargo la direccion del inicio de cada tarea al principio
	;del stack de cada tarea
	ldi r16, low(tarea2)
	sts t2Stack, r16
	ldi r16, high(tarea2)
	sts t2Stack-1, r16	

;-----------PC tarea3:--------------------------------------
	ldi r16, low(tarea3)
	sts t3Stack, r16
	ldi r16, high(tarea3)
	sts t3Stack-1, r16	

;-----------PC tarea4:--------------------------------------
	ldi r16, low(tarea4)
	sts t4Stack, r16
	ldi r16, high(tarea4)
	sts t4Stack-1, r16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;IMPLEMENTACION DEL MUTEX								 ;
;lo hago enntre la trea 1 y la tarea 2					 ;
;la una no puede acceder a la seccion critica si la otra ;
;la esta usando											 ;
;--------------------------------------------------------;
;para poder hacer esto voy a reservar 2 registros		 ;
;el registro 22 y 23									 ;
.def quiereEntrar = r22									 ;						 ;
.def turno = r23										 ;
														 ;
clr quiereEntrar										 ;
clr turno									 	 		 ;
;a estos no los incluyo cuando guardo el contexto 		 ;
;tambien hago 2 macros: ENTRAR Y SALIR 					 ;
;--------------------------------------------------------;
;me baso en el algoritmo de Peterson:	      			 ;
;https://en.wikipedia.org/wiki/Peterson%27s_algorithm	 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;MACRO 1 ENTRAR: prende el bit n para la tarea, indica si la tarea n
;va a usar el recurso. 0<= n <= 7
.macro entrar
	ori quiereEntrar, (1<<@0)
	.endmacro

;MACRO 2 SALIR: apaga el bit n para la tarea, indica si la tarea n
;va a usar el recurso. 0<= n <= 7
.macro salir
	com quiereEntrar
	ori quiereEntrar, (1<<@0)
	com quiereEntrar
	.endmacro


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;--------------------------------------------------------;
;FIN DE LAS INICIALIZACIONES :v				 			 ;
;no se vuelve aqui a no ser de que ocurra un reset		 ;
;--------------------------------------------------------;
	; este pedazo es pre tarea 							 ;
	ser r18 											 ;
	out DDRB, r18 										 ;
														 ;
	;fin pre tarea 									  	 ;
	sei ;prendo las interrupciones globales				 ;
	rjmp tarea1 ;salto a la tarea1						 ;
;														 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;QUE COMIENZEN LAS TAREAS!!!!!
;voy a hacer parpadear leds en tiempos diferentes, del 2 al 5 en el
;PortB

;uso el registro 24 como un tempoal

tarea1:
	;digo que quiero usar la seccion critica
	entrar 0
	;digo que la tarea tambien es 2
	ldi turno, 2

	;este es el ciclo en el que comparo
	Ciclo1:
		;compracion1 si esta prendida la tarea 2
		mov r24, quiereEntrar
		andi r24, (1<<1)

		;pregunto si esta prendoido el bit 1
		cpi r24, 0b00000010
		breq Comp1
		;si no entonces salto a la tarea
		rjmp Tcritica1

	Comp1:
		;comparacion2 si el turno es de la siguiente tarea
		;se hace asi porque la tarea no se arranca a ejecutar
		cpi turno, 2
		;si no vuelvo a comparar
		breq Ciclo1
		;si no pa la tarea
		rjmp Tcritica1

	Tcritica1:
		ldi r16, 0b00010000
		out PortB, r16
		;una vez que haga la parte critica digo que ya no
		;tengo intencion de usarlo
		salir 0
		rjmp tarea1

tarea2:
	;digo que quiero usar la seccion critica
	entrar 1
	;digo que la tarea tambien es 2
	ldi turno, 1

	;este es el ciclo en el que comparo
	Ciclo2:
		;compracion1 si esta prendida la tarea 2
		mov r24, quiereEntrar
		andi r24, (1<<0)

		;pregunto si esta prendoido el bit 0
		cpi r24, 0b00000001
		breq Comp2
		;si no entonces salto a la tarea
		rjmp Tcritica2

	Comp2:
		;comparacion2 si el turno es de la siguiente tarea
		;se hace asi porque la tarea no se arranca a ejecutar
		cpi turno, 1
		;si no vuelvo a comparar
		breq Ciclo2
		;si no pa la tarea
		rjmp Tcritica2

	Tcritica2:
		ldi r16, 0b00000001
		out PortB, r16
		;una vez que haga la parte critica digo que ya no
		;tengo intencion de usarlo
		salir 1
		rjmp tarea2


tarea3:
	;prende el led4 y espera 1 ciclos luego lo apaga
	ldi r16,0b0000010
	out PortB, r16
	rjmp tarea3

tarea4:
	;prende el led5 y espera 0 ciclos luego lo apaga
	ldi r16,0b00000100
	out PortB, r16
	rjmp tarea4


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ESTA ES LA PARTE IMPORTANTE				 			 ;
;aqui ocurre la magia del cambio de tarea 				 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CambioContexto:
	;1 pusheo todos los registros
	push r31
    push r30
    push r29
    push r28
    push r27
    push r26
    push r25
    push r24
   ;el hueco mutex
    push r21
    push r20
    push r19
    push r18
    push r17
    push r16
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push r7
    push r6
    push r5
    push r4
    push r3
    push r2
    push r1
    push r0 

    ;2 pusheo SREG
    in r18, SREG
    push r18
;----3---------------MAGIA INCOMING, CAMBIO DE CONTEXTO------------------------;
	;paso el index de la tarea
	lds r16, indexTareas
	;cargo el registro z
	ldi ZL, low(tareasBackUp)
	ldi ZH, high(tareasBackUp)
	;resto el index de las tareas(r16) con el z bajo
	clr r0
	sub ZL, r16
	sbc ZH, r0
	sub ZL, r16
	sbc ZH, r0

	;cargo a donde este apuntando el Stack Pointer y lo paso a donde apunta Z
	;para el alto
	in r17, SPH
	st Z, r17
	;para el bajo
	in r17, SPL
	st -Z, r17

	;comparo con el numero total de tareas

	;saco el numero de tareas kkkkkkkkkkkkkkkkk
	ldi XL, low(pepe)
	ldi XH, high(pepe)

	ld r18, X

	;sigo
	inc r16
	;cpi r16, tareasTotales ;como es una constante uso cpi

	cp r16, r18 ;comparo con el numero de tareas
	brne Skip1;si son diferentes, si no:
	;reseteo los punteros a la base
	ldi ZL, low(tareasBackUp)
	ldi ZH, high(tareasBackUp)
	;digo que mi index de tareas vuelve a ser el inicial
	clr r16
	sts indexTareas, r16
	;cargo el r17 para el Skip2
	ld r17, z
	rjmp Skip2


Skip1:
	;si los indexes son diferentes, osea, que no
	;se ha cumplido un ciclo de tareas:

	;guardo la tarea en la que voy
	sts indexTareas, r16
	;---?
	ld r17, -z
	;sigo para el Skip2
Skip2:
	;cargo al stack pointer la tarea siguiente
	;alto
	out SPH, r17
	;bajo
	ld r17,-Z
	out SPL, r17

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;EN ESTE PUNTO YA SE CAMBIO LA TAREA!!				 	 ;
;ya lo que queda es restituir como estaban los registros ;
;para dicha.				 							 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;saco en orden opuesto al que meti
	;1. SREG
	pop r17
	out SREG, r17
	;2. GREG
	pop r0
    pop r1
    pop r2
    pop r3
    pop r4
    pop r5
    pop r6
    pop r7
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15
    pop r16
    pop r17
    pop r18
    pop r19
    pop r20
    pop r21
    ;el hueco mutex
    pop r24
    pop r25
    pop r26
    pop r27
    pop r28
    pop r29
    pop r30
    pop r31
    ;vuelvo a la tarea, hasta la proxima 
    ;interrupcion
    reti

BotonY:
	push r18
	ldi r18,3
	sts pepe, r18
	pop r18
reti