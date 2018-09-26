; ***************************************
; Projeto 1 - Microcomputadores         *
;                                       *
; MCU: PIC16F628A	Clock: 10Hz         *
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
DELAY_1S    equ     D'1'

; --- ENTRADAS ---
#define     partida         PORTB,RB0
#define     fumaca          PORTA,RA0
#define     luminosidade    PORTA,RA1
#define     presenca1       PORTA,RA2
#define     presenca2       PORTA,RA3
#define     presenca3       PORTA,RA5

; --- SAIDAS ---
#define     buzina          PORTB,RB3
#define     on              PORTB,RB2

#define     luz1            PORTB,RB5
#define     luz2            PORTB,RB6
#define     luz3            PORTB,RB7

; --- DEFINICOES GERAIS ---
#define     thab        INTCON,TOIE     ; habilita interrupcao
#define     tflag       INTCON,T0IF     ; timer overflow
#define     pflag       INTCON,INTF     ; interrupcao em RB0
#define     zero        STATUS,Z        ; resultado da ultima operacao foi 0

; --- REGISTRADORES DE USO GERAL ---
    cblock 0x20
        temporario
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
    movlw   B'11111111'     
    movwf   TRISA           ; port a como input
    movlw   B'00000001'
    movwf   TRISB           ; pb0 como input o resto como output
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
    
loop:
    btfss   partida         ; partida esta setado?
    call    start
    goto    loop

start:
    btfss   luminosidade    ; btfsc se 0 for sem luz
    call    check_presenca
    btfss   fumaca
    call    tratar_fumaca
    
    return

check_presenca:
    btfss   presenca1       ; presenca 1 esta setado?
    call    light1
    btfss   presenca2
    call    light2
    btfss   presenca3
    call    light3
    call    apaga_luz
    return

light1:
    bsf     luz1
    call    delay             ; delay de 1min, checar se o timer acabou
    return

light2:
    bsf     luz2
    call    delay
    return

light3:
    bsf     luz3
    call    delay
    return

tratar_fumaca:
    bsf     

apaga_luz:
    bcf     luz1
    bcf     luz2
    bcf     luz3
    return

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
    