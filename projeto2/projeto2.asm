; ***************************************
; PROJETO 2 - MICROCOMPUTADORES         *
;                                       *
; MCU: PIC16F877A   CLOCK: 4MHZ         *
;                                       *
; AUTORES: DAVID RIFF DE F. TENORIO     *
;          DIEGO MAIA HAMILTON          *
;                                       *
; VERSAO: 1.0 (COM INTERRUPCAO)         *
; DATA: NOVEMBRO DE 2018                *
; ***************************************
 
#INCLUDE <P16F877A.INC>
 
    LIST        P=16F877A
 
; --- FUSE BITS ---
    __CONFIG     _BOREN_OFF & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF
 
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
DELAY_2S    EQU     D'236'
LUZ_BAIXA   EQU     D'85'
LUZ_MEDIA   EQU     D'170'
TEMP_BAIXA  EQU     D'64'
TEMP_MEDIA  EQU     D'128'
TEMP_ALTA   EQU     D'192'     
 
; --- ENTRADAS ---
#DEFINE     PRESENCA        PORTB, RB0   ; ENTRADA DIGITAL COM INTERRUPCAO
#DEFINE     TEMPERATURA     PORTA, RA0   ; ENTRADA ANALOGICA
#DEFINE     LUMINOSIDADE    PORTA, RA1   ; ENTRADA ANALOGICA
#DEFINE     PARTIDA         PORTB, RB1   ; ENTRADA DIGITAL
 
; --- SAIDAS ---
#DEFINE     VENTILADOR      PORTC, RC2   ; SAIDA PWM
#DEFINE     ARCONDICIONADO  PORTB, RB2   ; DIGITAL
#DEFINE     LUZ1            PORTB, RB3   ; DIGITAL
#DEFINE     LUZ2            PORTB, RB4   ; DIGITAL
#DEFINE     ON              PORTB, RB5   ; DIGITAL
 
; --- DEFINICOES GERAIS ---
#DEFINE     THAB        INTCON, TOIE     ; HABILITA INTERRUPCAO
#DEFINE     TFLAG       INTCON, T0IF     ; TIMER OVERFLOW
#DEFINE     EXTFLAG     INTCON, INTF     ; INTERRUPCAO EXTERNA
#DEFINE     RFLAG       INTCON, RBIF     ; INTERRUPCAO DE MUDANCA DE ESTADO RB4 - RB7
#DEFINE     INTEDGE     OPTION_REG, 6    ; BORDA DA INTERRUPCAO EXTERNA
#DEFINE     PWM_VAL     CCPR1L           ; COMPRIMENTO DO PULSO DO PWM
#DEFINE     START_CONV  ADCON0, 2        ; BIT DE CONTROLE DA CONVERSÃO A/D
 
 
; --- REGISTRADORES DE USO GERAL ---
    CBLOCK 0X20
        W_TEMP
        STATUS_TEMP
        PCLATH_TEMP
        
        MINUTO
        TEMPERATURA_F
        LUMINOSIDADE_F

        ; --- ARGUMENTOS PARA ROTINA DE COMPARACAO ---
        NUMERO1
        NUMERO2
        RESULTADO
    ENDC
 
; --- VETOR DE RESET ---
    ORG         H'0000'                 ; ORIGEM NO ENDERECO 0 DE MEMORIA
    GOTO        SETUP                   ; DESVIA DO VETOR DE INTERRUPCAO
 
; --- VETOR DE INTERRUPCAO ---              
    ORG         H'0004'
 
; --- SALVA CONTEXTO ---
    MOVWF       W_TEMP                  ; COPY W TO TEMP REGISTER
    SWAPF       STATUS, W               ; SWAP STATUS TO BE SAVED INTO W
    CLRF        STATUS                  ; BANK 0, REGARDLESS OF CURRENT BANK, CLEARS IRP, RP1, RP0
    MOVWF       STATUS_TEMP             ; SAVE STATUS TO BANK ZERO STATUS_TEMP REGISTER
    MOVF        PCLATH, W               ; ONLY REQUIRED IF USING PAGES 1, 2 AND/OR 3
    MOVWF       PCLATH_TEMP             ; SAVE PCLATH INTO W
    CLRF        PCLATH                  ; PAGE ZERO, REGARDLESS OF CURRENT PAGE 
 
; --- TRATAMENTO DA ISR ---
    BANKSEL     OPTION_REG
    BTFSC       EXTFLAG
    GOTO        TRATA_BORDA             ; SE HOUVE INTERRUPCAO EXTERNA, TRATA BORDA SUBIDA/DESCIDA
    BTFSS       INTEDGE                 ; SE NAO HOUVE, MAS HA PRESENCA, TRATA
    GOTO        EXIT_ISR
    GOTO        TRATA_ISR
TRATA_BORDA:
	BCF			EXTFLAG
    BTFSC       INTEDGE                 ; CHECA BORDA DA INTERRUPÇÃO DO PINO RB0
    GOTO        TRATA_SUBIDA
    CALL        BORDA_DESCIDA           ; COLOCA SISTEMA EM MODO DE BAIXA ENERGIA E CONFIGURA BORDA DE SUBIDA
    GOTO        EXIT_ISR
TRATA_SUBIDA:
    CALL        BORDA_SUBIDA            ; CONFIGURA BORDA DE DESCIDA E CONTINUA EXECUCAO DA ISR
TRATA_ISR:
    BTFSC       TFLAG
    CALL        CONTADOR
 
; --- RECUPERACAO DE CONTEXTO ---
EXIT_ISR:
    MOVF        PCLATH_TEMP, W           ; RESTORE PCLATH
    MOVWF       PCLATH                   ; MOVE W INTO PCLATH
    SWAPF       STATUS_TEMP, W           ; SWAP STATUS_TEMP REGISTER INTO W
                                         ; (SETS BANK TO ORIGINAL STATE)
    
    MOVWF       STATUS                   ; MOVE W INTO STATUS REGISTER
    SWAPF       W_TEMP, F                ; SWAP W_TEMP
    SWAPF       W_TEMP, W                ; SWAP W_TEMP INTO W
    RETFIE
 
; --- SUBROTINAS ---

BORDA_SUBIDA:
    BCF         INTEDGE                  ; CONFIGURA BORDA DE DESCIDA
    RETURN
BORDA_DESCIDA:
    BSF         INTEDGE                  ; CONFIGURA BORDA DE SUBIDA
    ; desligar tudo (PWM, luzes etc), resetar timer
    RETURN

MEDE_TEMPERATURA:
    BANKSEL     ADCON0
    MOVF        ADCON0,W                ; ARMAZENA VALOR DE ADCON0 EM W
    ANDLW       B'11000111'             ; LIMPA BITS DE SELECAO DO CANAL
    XORLW       B'00000000'             ; CONFIGURA CANAL 0
    MOVWF       ADCON0                  ; SALVA CONFIGURACAO EM ADCON0

    BSF         START_CONV              ; INICIA CONVERSAO
    BTFSC       START_CONV              ; TESTA FIM DE CONVERSAO
    GOTO        $-1                     ; ESPERA FIM DE CONVERSAO
    BANKSEL     ADRESL
    MOVF        ADRESL, W               ; MOVE RESULTADO DA CONVERSAO PARA W
    BANKSEL     TEMPERATURA_F
    MOVWF       TEMPERATURA_F
    BSF         LUZ1
    RETURN

MEDE_LUMINOSIDADE:
    BANKSEL     ADCON0
    MOVF        ADCON0,W                ; ARMAZENA VALOR DE ADCON0 EM W
    ANDLW       B'11000111'             ; LIMPA BITS DE SELECAO DO CANAL
    XORLW       B'00001000'             ; CONFIGURA CANAL 1
    MOVWF       ADCON0                  ; SALVA CONFIGURACAO EM ADCON0

    BSF         START_CONV              ; INICIA CONVERSAO
    BTFSC       START_CONV              ; TESTA FIM DE CONVERSAO
    GOTO        $-1                     ; ESPERA FIM DE CONVERSAO
    BANKSEL     ADRESL
    MOVF        ADRESL, W               ; MOVE RESULTADO DA CONVERSAO PARA W
    BANKSEL     LUMINOSIDADE_F
    MOVWF       LUMINOSIDADE_F

    MOVWF       LUMINOSIDADE_F, NUMERO1
    MOVLW       D'128'
    MOVWF       NUMERO2
    CALL        MAIOR_QUE
    BTFSC       RESULTADO, 1
    GOTO        LUMINOSIDADE_MIN
    BTFSC       RESULTADO, 0
    GOTO        LUMINOSIDADE_MAX
    GOTO        LUMINOSIDADE_IGUAL
    RETURN

CONTADOR:
    BCF        TFLAG
    CALL       RESET_TIMER
    DECFSZ     MINUTO                   ; SE PASSOU UM MINUTO, TRATA TEMPERATURA
    GOTO       TRATA_LUMINOSIDADE       ; CASO CONTRÁRIO, TRATA LUMINOSIDADE
    GOTO       TRATA_TEMPERATURA
TRATA_TEMPERATURA:
    CALL       MEDE_TEMPERATURA
    MOVLW      D'30'                   
    MOVWF      MINUTO                   ; RECARREGA CONTADOR DE MINUTO
    GOTO       END_CONTADOR
TRATA_LUMINOSIDADE:
    CALL       MEDE_LUMINOSIDADE
END_CONTADOR:
    RETURN

MAIOR_QUE:
    CLRF       RESULTADO
    MOVF       NUMERO1, W
    SUBWF      NUMERO2, W
    BTFSC      STATUS, Z
    GOTO       IGUAL
    BTFSC      STATUS, C
    GOTO       MENOR_QUE
    MOVLW      H'01'                    ; NUMERO1 E MAIOR QUE NUMERO2
    MOVWF      RESULTADO
    GOTO       END_COMP 
IGUAL:
    MOVLW      H'00'                    ; NUMERO1 IGUAL A NUMERO2
    MOVWF      RESULTADO
    GOTO       END_COMP
MENOR_QUE:
    MOVLW      H'02'                    ; NUMERO1 MENOR QUE NUMERO2
    MOVWF      RESULTADO
END_COMP:
    RETURN

RESET_TIMER:
    MOVLW      DELAY_2S
    MOVWF      TMR0
    RETURN
 
; --- PROGRAMA PRINCIPAL ---
SETUP:
    BANKSEL     TRISD
	CLRF		PORTD
    CLRF        TRISD                   ; CONFIGURA PORTA D COMO SAÍDA            
 
    BANKSEL     TRISC
	CLRF		PORTC
    CLRF        TRISC                   ; CONFIGURA PORTA C COMO SAÍDA            
    
    BANKSEL     OPTION_REG
    MOVLW	    B'11110000'             ; HABILITA CLOCK EXTERNO
    MOVWF	    OPTION_REG              ; DEFINE OPCOES DE OPERACAO: PULLUPS DA PORTAB DESATIVADOS
                                        ; BORDA DE SUBIDA EM RB0, PRESCALER DE 1:2 DO TMR0

    ; -- CONFIGURACAO DO PWM --
    BANKSEL     T1CON
    BSF         T1CON,0                 ; ATIVA TIMER1
    MOVWF       T1CON
    MOVLW       B'00001100'             ; CONFIGURA 2 LSB DO DUTY CYCLE DO PWM PARA 0
                                        ; CONFIGURA TIMER 1 NO MODO PWM
    MOVWF       CCP1CON
 
    ; -- CONFIGURACAO DE I/O --
    BANKSEL     PORTB                   ; SELECIONA BANK0
    CLRF        PORTB                   ; LIMPA SAIDAS EM PORTB
    BANKSEL     TRISB
    MOVLW       H'03'
    MOVWF       TRISB                   ; CONFIGURA RB<1:0> COMO INPUTS
 
    BANKSEL     INTCON
    MOVLW       H'00'
    MOVWF       INTCON                  ; INICIA COM TODAS AS INTERRUPCOES DESATIVADAS
  
    BANKSEL     PORTC
    CLRF        PORTC
    BANKSEL     TRISC
    CLRF        TRISC                   ; CONFIGURA RC0 COMO OUTPUT
 
     ; -- CONFIGURACAO DO CONVERSOR A/D --
    BANKSEL     PORTA                   ; SELECIONA BANK0
    CLRF        PORTA                   ; LIMPA OS OUTPUTS NA PORTA
    BANKSEL     ADCON1                  ; SELECIONA O BANK1
    MOVLW       B'10000100'             ; CONFIGURA RA<1:0> COMO ENTRADAS ANALOGICAS, VDD/VSS COMO REFERENCIA
                                        ; CONFIGURA FOSC/2
                                        ; CONFIGURA JUSTIFICADO A DIREITA
    MOVWF       ADCON1
    BANKSEL     TRISA
    MOVLW       B'00000011'             ; CONFIGURA RA<1:0> COMO INPUTS
    MOVWF       TRISA
    BANKSEL     ADCON0
    MOVLW		B'00000001'
    MOVWF       ADCON0                  ; CONFIGURA FOSC/2, LIGA CONVERSOR              
 
    BANKSEL     PWM_VAL
    MOVLW       D'128'                  ;
    MOVWF       PWM_VAL                 ; SETA PWM PARA 2^8

    CLRF        TMR0
    BCF         TFLAG
    MOVLW       DELAY_2S
    MOVWF       TMR0
    
    MOVLW       D'30'
    MOVWF       MINUTO

MAIN:
    BTFSS      PARTIDA
    GOTO       MAIN
    BSF        ON
    BANKSEL    INTCON
    MOVLW      B'10111000'              ; ATIVA INTERRUPCAO: GLOBAL, TIMER0, RB0, RB4-7
    MOVWF      INTCON
    ; BANKSEL    PIE1
    ; MOVLW      B'01000000'              ; ATIVA INTERRUPCAO DO CONVERSOR A/D
    ; MOVWF      PIE1
    GOTO       $

    END