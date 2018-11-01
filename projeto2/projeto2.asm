; ***************************************
; PROJETO 2 - MICROCOMPUTADORES         *
;                                       *
; MCU: PIC16F877A	CLOCK: 4MHZ         *
;                                       *
; AUTORES: DAVID RIFF DE F. TENORIO     *
;          DIEGO MAIA HAMILTON          *
;                                       *
; VERSAO: 1.0 (COM INTERRUPÇÃO)         *
; DATA: NOVEMBRO DE 2018                *
; ***************************************

#INCLUDE <P16F628A.INC>

    LIST		P=16F877A

; --- FUSE BITS ---
    __CONFIG     _BOREN_OFF & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_ON

; --- PAGINACAO DE MEMORIA ---
BANK0   MACRO
        BCF     STATUS, RP0
        BCF     STATUS, RP1
        ENDM

BANK1   MACRO
        BSF     STATUS, RP0
        BCF     STATUS, RP1
        ENDM

BANK2   MACRO
        BCF     STATUS, RP0
        BSF     STATUS, RP1
        ENDM

BANK3   MACRO
        BSF     STATUS, RP0
        BSF     STATUS, RP1
        ENDM              

; --- CONSTANTES ---
DELAY_1S    EQU     D'246'

; --- ENTRADAS ---
#DEFINE     PRESENCA        PORTB, RB0   ; ENTRADA DIGITAL COM INTERRUPCAO
#DEFINE     TEMPERATURA     PORTA, RA0   ; ENTRADA ANALOGICA
#DEFINE     LUMINOSIDADE    PORTA, RA1   ; ENTRADA ANALOGICA
#DEFINE     PARTIDA         PORTB, RB1   ; ENTRADA DIGITAL

; --- SAIDAS ---
#DEFINE     VENTILADOR      PORTC, RC0   ; SAIDA PWM 
#DEFINE     ARCONDICIONADO  PORTB, RB2   ; DIGITAL
#DEFINE     LUZ1            PORTB, RB3   ; DIGITAL
#DEFINE     LUZ2            PORTB, RB4   ; DIGITAL
#DEFINE     ON              PORTB, RB5   ; DIGITAL

; --- DEFINICOES GERAIS ---
#DEFINE     THAB        INTCON, TOIE     ; HABILITA INTERRUPCAO
#DEFINE     TFLAG       INTCON, T0IF     ; TIMER OVERFLOW
#DEFINE     EXTFLAG     INTCON, INTF     ; INTERRUPCAO EXTERNA
#DEFINE     RFLAG       INTCON, RBIF     ; INTERRUPCAO DE MUDANCA DE ESTADO RB4 - RB7
#DEFINE     ZERO        STATUS, Z        ; RESULTADO DA ULTIMA OPERACAO FOI 0

; --- REGISTRADORES DE USO GERAL ---
    CBLOCK 0X20

    ENDC

; --- VETOR DE RESET ---
    ORG         H'0000'                 ; ORIGEM NO ENDERECO 0 DE MEMORIA
    GOTO        SETUP                   ; DESVIA DO VETOR DE INTERRUPCAO

; --- VETOR DE INTERRUPCAO ---
    ORG         H'0004'

; --- SALVA CONTEXTO ---
    MOVWF       W_TEMP                  ; COPIA O CONTE�DO DE WORK PARA W_TEMP 
    SWAPF       STATUS, W                ; MOVE O CONTE�DO DE STATUS COM OS NIBBLES INVERTIDOS PARA W
    BANK0                               ; SELECIONA O BANCO 0 DE MEM�RIA
    MOVWF       STATUS_TEMP             ; COPIA O CONTE�DO DE STATUS COM OS NIBBLES INVERTIDOS PARA STATUS_TEMP

; --- TRATAMENTO DA ISR ---

; --- RECUPERACAO DE CONTEXTO ---
EXIT_ISR:
    SWAPF       STATUS_TEMP, W_TEMP      ; COPIA EM W O CONTEÚDO DE STATUS_TEMP COM OS NIBBLES INVERTIDOS
    MOVWF       STATUS                  ; RECUPERANDO O CONTEÚDO DE STATUS
    SWAPF       W_TEMP, F                ; W_TEMP = W_TEMP COM OS NIBBLES INVERTIDOS
    SWAPF       W_TEMP, W                ; RECUPERA O CONTEÚDO DE WORK

    RETFIE

; --- SUBROTINAS ---


; --- PROGRAMA PRINCIPAL ---
SETUP:
    BANKSEL     PORTA                   ; SELECIONA BANK0
    CLRF        PORTA                   ; LIMPA OS OUTPUTS NA PORTA
    BANKSEL     ADCON1                  ; SELECIONA O BANK1
    MOVLW       0x8D                    ; CONFIGURA RA<1:0> COMO ENTRADAS ANALOGICAS
                                        ; CONFIGURA FOSC/2
                                        ; CONFIGURA JUSTIFICADO A DIREITA
    MOVWF       ADCON1
    BANKSEL     TRISA
    MOVLW       0x03                    ; CONFIGURA RA<1:0> COMO INPUTS
    MOVWF       TRISA            

    BANKSEL     ADCON0
    CLRF        ADCON0                  ; CONFIGURA FOSC/2              

    BANKSEL     PORTB                   ; SELECIONA BANK0
    CLRF        PORTB                   ; LIMPA SAIDAS EM PORTB
    BANKSEL     TRISB
    MOVLW       0x03
    MOVWF       TRISB                   ; CONFIGURA RB<1:0> COMO INPUTS

    BANKSEL     INTCON
    MOVLW       0x00
    MOVWF       INTCON                  ; INICIA COM TODAS AS INTERRUPCOES DESATIVADAS

    BANKSEL     PORTC
    CLRF        PORTC
    BANKSEL     TRISC
    CLRF        TRISC                   ; CONFIGURA RC0 COMO OUTPUT


    ; BANK1
    ; MOVLW       B'00000000'     
    ; MOVWF       TRISA                    ; PORT A COMO SAIDA
    ; MOVLW       B'11110101'
    ; MOVWF       TRISB                    ; RB0, RB2, RB4, RB5, RB6 E RB7 COMO ENTRADA
    ; MOVLW       B'10110001'     
    ; MOVWF       OPTION_REG               ; DEFINE OPCOES DE OPERACAO PRESCALER 1:4

    ; MOVLW       B'00000000'
    ; MOVWF       INTCON                   ; DEFINE OPCOES DE INTERRUPCAO

    ; MOVLW       B'00001000'
    ; MOVWF       PCON                     ; UTILIZAR CRISTAL INTERNO DE 4MHZ
    ; BANK0

    ; MOVLW       B'00000111'
    ; MOVWF       CMCON                    ; ENTRADAS ANALOGICAS DESATIVADAS

    ; MOVLW       B'00000000'
    ; MOVWF       PORTB                    ; INICIA OUTPUTS EM 0
    ; MOVLW       B'00000000'
    ; MOVWF       PORTA                    ; INICIA OUTPUTS EM 0

	; CLRF        TMR0
    ; BCF         TFLAG

    END