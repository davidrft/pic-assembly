; ***************************************
; Projeto 1 - Microcomputadores         *
;                                       *
; MCU: PIC16F628A	Clock: 4MHz         *
;                                       *
; Autores: David Riff de F. Tenorio     *
;          Diego Maia Hamilton          *
;                                       *
; Versao: 1.0                           *
; Data: Novembro de 2018                *
; ***************************************

#include <p16f628a.inc>

    list		p=16f628a

; --- FUSE BITS ---
    __config     _BOREN_OFF & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_ON

; --- PAGINACAO DE MEMORIA ---
#define     bank0       bcf     STATUS,RP0
#define     bank1       bsf     STATUS,RP0

; --- CONSTANTES ---
DELAY_1S    equ     D'246'

; --- ENTRADAS ---
#define     luminosidade    PORTB,RB7   ; sensor de luminosidade
#define     fumaca          PORTB,RB0   ; sensor de fumaça
#define     presenca1       PORTB,RB4   ;
#define     presenca2       PORTB,RB5   ; presenca nivel alto -> presenca detectada
#define     presenca3       PORTB,RB6   ;

; --- SAIDAS ---
#define     buzina          PORTA,RA3   ; saida do alarme
#define     on              PORTB,RB1   ; saida de on/off

#define     luz1            PORTA,RA0   ; saida da luz 1
#define     luz2            PORTA,RA1   ; saida da luz 2
#define     luz3            PORTA,RA2   ; saida da luz 3

; --- DEFINICOES GERAIS ---
#define     thab        INTCON,TOIE     ; habilita interrupcao
#define     tflag       INTCON,T0IF     ; timer overflow
#define     extflag     INTCON,INTF     ; interrupcao externa
#define     rflag       INTCON,RBIF     ; interrupcao de mudanca de estado RB4 - RB7
#define     zero        STATUS,Z        ; resultado da ultima operacao foi 0
#define     ativo1      B'00000001'     ; sensor de presenca 1 ativo
#define     ativo2      B'00000010'     ; sensor de presenca 2 ativo
#define     ativo3      B'00000100'     ; sensor de presenca 3 ativo
#define     ativa_f     B'00001000'     ; sensor de fumaca 	ativo
#

; --- REGISTRADORES DE USO GERAL ---
    cblock 0x20
        W_TEMP
        STATUS_TEMP

        contador1
		contador2
		contador3
		contador_fumaca
		presenca_ativa
    endc

; --- VETOR DE RESET ---
    org         H'0000'                 ; origem no endereco 0 de memoria
    goto        main                    ; desvia do vetor de interrupcao

; --- VETOR DE INTERRUPCAO ---
    org         H'0004'

; --- SALVA CONTEXTO ---
    movwf       W_TEMP                  ; Copia o conteúdo de work para W_TEMP 
    swapf       STATUS,W                ; Move o conteúdo de status com os nibbles invertidos para W
    bank0                               ; Seleciona o banco 0 de memória
    movwf       STATUS_TEMP             ; Copia o conteúdo de STATUS com os nibbles invertidos para STATUS_TEMP

; --- TRATAMENTO DA ISR ---
    btfsc       extflag                 ; interrupcao pelo sensor de fumaca?
    call        test_fumaca             

    btfsc       rflag                   ; interrupcao pelos sensores de presença?
    call        check_presenca

    btfsc       tflag                   ; estouro do timer 0?
    call        contador

; --- RECUPERACAO DE CONTEXTO ---
exit_ISR:
    swapf       STATUS_TEMP,W_TEMP      ; Copia em W o conteúdo de STATUS_TEMP com os nibbles invertidos
    movwf       STATUS                  ; Recuperando o conteúdo de STATUS
    swapf       W_TEMP,F                ; W_TEMP = W_TEMP com os nibbles invertidos
    swapf       W_TEMP,W                ; Recupera o conteúdo de work

    retfie

; --- SUBROTINAS ---
check_presenca:
    btfss       presenca1               ; checa sensores da secao 1
    goto   	    check2
	btfss       luminosidade
    goto        check2
	bsf         presenca_ativa,ativo1   ; ativa contagem (liga a luz) da secao 1
	bsf		    luz1
check2:  
	btfss       presenca2               ; checa sensores da secao 2
	goto 	    check3
	btfss       luminosidade
	goto	    check3
	bsf         presenca_ativa,ativo2  ; ativa contagem (liga a luz) da secao 2
	bsf		    luz2
check3:  
	btfss       presenca3              ; checa sensores da secao 3
    goto        end_check
	btfss       luminosidade
    goto        end_check
	bsf         presenca_ativa,ativo3  ; ativa contagem (liga a luz) da secao 3
	bsf		    luz3
end_check:
    return

contador:
    bcf         tflag
	movlw		DELAY_1S
	movwf		TMR0
test_ativo1:
	btfsc       presenca_ativa,ativo1
    decfsz      contador1,1
    goto        test_ativo2
    call        reset_cont1
test_ativo2: 
	btfsc	    presenca_ativa,ativo2
    decfsz      contador2,1
    goto        test_ativo3
    call        reset_cont2
test_ativo3:
	btfsc       presenca_ativa, ativo3
    decfsz      contador3, 1
    goto        test_fumaca
    call        reset_cont3
test_fumaca:
    btfss       fumaca
    goto        reset_contf
    decfsz      contador_fumaca
    goto        end_fumaca
	bsf			buzina
reset_contf:
    movlw       D'10'
    movwf       contador_fumaca
    btfss       fumaca
	bcf			buzina
end_fumaca:
    movlw       D'8'
    xorwf       contador_fumaca, w
    btfsc       zero
    bcf         buzina
    return

reset_cont1:
    movlw       D'60'
    movwf 	    contador1
    bcf 	    presenca_ativa, ativo1
    bcf 	    luz1
    return
reset_cont2:
    movlw       D'60'
    movwf 	    contador2
    bcf 	    presenca_ativa, ativo2
    bcf 	    luz2
    return
reset_cont3:
    movlw       D'60'
    movwf  	    contador3
    bcf  	    presenca_ativa, ativo3
    bcf 	    luz3
    return


; --- PROGRAMA PRINCIPAL ---
main:
    bank1
    movlw       B'00000000'     
    movwf       TRISA                    ; Port A como saida
    movlw       B'11110001'
    movwf       TRISB                    ; RB0, RB4, RB5, RB6 e RB7 como entrada
    movlw       B'10110001'     
    movwf       OPTION_REG               ; define opcoes de operacao prescaler 1:4

    movlw       B'10111000'
    movwf       INTCON                   ; define opcoes de interrupcao

    movlw       B'00001000'
    movwf       PCON                     ; utilizar cristal interno de 4MHz
    bank0

    movlw       B'00000111'
    movwf       CMCON                    ; entradas analogicas desativadas

    movlw       B'00000000'
    movwf       PORTB                    ; inicia outputs em 0
    movlw       B'00000000'
    movwf       PORTA                    ; inicia outputs em 0

	movlw  	    D'60'
	movwf	    contador1		         ; inicializa contador do sensor de presenca1
	movlw	    D'60'
	movwf	    contador2		         ; inicializa contador do sensor de presenca2
	movlw	    D'60'
	movwf	    contador3	             ; inicializa contador do sensor de presenca3
    movlw	    D'10'
	movwf	    contador_fumaca	         ; inicializa contador do sensor de fumaca
	movlw	    D'0'
	movwf	    presenca_ativa
	clrf        TMR0
    bcf         tflag
    movlw       DELAY_1S
    movwf       TMR0

start:
    bsf         on
loop:
    goto        loop 

    end