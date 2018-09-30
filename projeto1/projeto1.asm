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
#define     fumaca          PORTA,RA0
#define     presenca1       PORTB,RB0   ;
#define     presenca2       PORTB,RB1   ; presenca nivel alto -> presenca detectada
#define     presenca3       PORTB,RB2   ;
#define     luminosidade1   PORTA,RA1   ;
#define     luminosidade2   PORTA,RA2   ; luminosidade nivel baixo -> esta claro (luz nao precisa ser ligada)
#define     luminosidade3   PORTA,RA3   ;

; --- SAIDAS ---
#define     buzina          PORTB,RB3
;#define    alarm          PORTB,RB4
#define     on              PORTA,RA4

#define     luz1            PORTB,RB5
#define     luz2            PORTB,RB6
#define     luz3            PORTB,RB7

; --- DEFINICOES GERAIS ---
#define     thab        INTCON,TOIE     ; habilita interrupcao
#define     tflag       INTCON,T0IF     ; timer overflow
#define     zero        STATUS,Z        ; resultado da ultima operacao foi 0
#define     ativo1      H'0001'         ; sensor de presenca 1 ativo
#define     ativo2      H'0002'         ; sensor de presenca 2 ativo
#define     ativo3      H'0003'         ; sensor de presenca 3 ativo
#define     ativa_f     H'0004'         ; sensor de fumaça ativo
#

; --- REGISTRADORES DE USO GERAL ---
    cblock 0x20
        contador1
		contador2
		contador3
		contador fumaca
		presenca_ativa
    endc

; --- VETOR DE RESET ---
    org         H'0000'     ; origem no endereco 0 de memoria
    goto        main        ; desvia do vetor de interrupcao

; --- VETOR DE INTERRUPCAO ---
    org         H'0004'     ; todas as interrupcoes apontam para este vetor
    retfie                  ; retorna a interrupcao

; --- PROGRAMA PRINCIPAL ---
main:
    bank1
    movlw   B'00001111'     
    movwf   TRISA           ; 1 - input, 0 - ouput
    movlw   B'00000111'
    movwf   TRISB           ; MSB   ...    LSB
    movlw   B'10110001'     
    movwf   OPTION_REG      ; define opcoes de operacao prescaler 1:4

    movlw   B'00000000'
    movwf   INTCON          ; define opcoes de interrupcao

    movlw   B'00001000'
    movwf   PCON            ; utilizar cristal interno de 4MHz
    bank0

    movlw   B'00000111'
    movwf   CMCON           ; entradas analogicas desativadas

    movlw   B'00000000'
    movwf   PORTB           ; inicia outputs em 0
    
	movlw	D'60'
	movwf	contador1		; inicializa contador do sensor de presenca1
	movlw	D'60'
	movwf	contador2		; inicializa contador do sensor de presenca2
	movlw	D'60'
	movwf	contador3		; inicializa contador do sensor de presenca3
    movlw	D'10'
	movwf	contador_fumaca	; inicializa contador do sensor de fumaça
start:
    call    check_presenca
    btfsc   fumaca
    call    tratar_fumaca
    btfsc	tflag
    call    contador
    goto start

    return

check_presenca:
    movf    presenca1,w            ; checa sensores da secao 1
    andwf   luminosidade1,0
    btfsc   zero
    bsf     presenca_ativa,ativo1  ; ativa contagem (liga a luz) da secao 1

    movf    presenca2, w            ; checa sensores da secao 2
    andwf   luminosidade2, 0
    btfsc   zero
    bsf     presenca_ativa, ativo2  ; ativa contagem (liga a luz) da secao 2

    movf    presenca3, w            ; checa sensores da secao 3
    andwf   luminosidade3, 0
    btfsc   zero
    bsf     presenca_ativa, ativo3  ; ativa contagem (liga a luz) da secao 3
    return

tratar_fumaca:
    bsf ativa_f
    return

contador:
    clrf TMR0
    bcf tflag

    btfss   presenca_ativa, ativo1
    goto    test_ativo2
    decfsz  contador1, w
    call    reset_cont1
    bsf     luz1
test_ativo2:
    btfss   presenca_ativa, ativo2
    goto    test_ativo3
    decfsz  contador2, w
    call    reset_cont2
    bsf     luz2
test_ativo3:
    btfss   presenca_ativa, ativo3
    goto    test_fumaca
    decfsz  contador3, w
    call    reset_cont3
    bsf     luz3
test_fumaca:
    ;implementar
    return

reset_cont1:
    movlw D'60'
    movwf contador1
    bcf presenca_ativa, ativo1
    bcf luz1
    goto test_ativo2
reset_cont2:
    movlw D'60'
    movwf contador2
    bcf presenca_ativa, ativo2
    bcf luz2
    goto test_ativo3
reset_cont3:
    movlw D'60'
    movwf contador3
    bcf presenca_ativa, ativo3
    bcf luz3
    goto test_fumaca

delay:
    clrf    TMR0
    bcf     tflag
    movlw   DELAY_1S
    movwf   TMR0
delay1:
    btfss   tflag
    goto    delay1
    return

    end