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
    BTFSS       EXTFLAG
    GOTO        EXIT_ISR

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

MEDE_TEMPERATURA:
    MOVLW       D'30'
    MOVWF       MINUTO
    BANKSEL     ADCON0
    BSF         START_CONV              ; INICIA CONVERSAO
    BTFSC       START_CONV              ; TESTA FIM DE CONVERSAO
    GOTO        $-1                     ; ESPERA FIM DE CONVERSAO
    BANKSEL     ADRESL
    MOVF        ADRESL, W               ; MOVE RESULTADO DA CONVERSAO PARA W
    BANKSEL     TEMPERATURA_F
    MOVWF       TEMPERATURA_F
    RETURN

MEDE_LUMINOSIDADE:
    BANKSEL     ADCON0
    BSF         START_CONV              ; INICIA CONVERSAO
    BTFSC       START_CONV              ; TESTA FIM DE CONVERSAO
    GOTO        $-1                     ; ESPERA FIM DE CONVERSAO
    BANKSEL     ADRESL
    MOVF        ADRESL, W               ; MOVE RESULTADO DA CONVERSAO PARA W
    BANKSEL     LUMINOSIDADE_F
    MOVWF       LUMINOSIDADE_F
    RETURN

CONTADOR:
    BCF        TFLAG
    CALL       RESET_TIMER
    DECFSZ     MINUTO
    CALL       MEDE_TEMPERATURA
    CALL       MEDE_LUMINOSIDADE
    RETURN

MAIOR_QUE:
    CLRF       RESULTADO
    MOVF       NUMERO1, W
    SUBWF      NUMERO2, W
    BTFSC      STATUS, Z
    GOTO       IGUAIS
    BTFSC      STATUS, C
    GOTO       MENOR
    MOVLW      H'01'           ; NUMERO1 E MAIOR QUE NUMERO2
    MOVWF      RESULTADO
    RETURN
IGUAL:
    MOVLW      H'00'
    MOVWF      RESULTADO
    RETURN
MENOR:
    MOVLW      H'02'
    MOVWF      RESULTADO
    RETURN

RESET_TIMER:
    MOVLW      DELAY_2S
    MOVWF      TMR0
    RETURN
 
; --- PROGRAMA PRINCIPAL ---
SETUP:
    BANKSEL     TRISD
    CLRF        TRISD                   ; CONFIGURA PORTA D COMO SAÍDA            
 
    BANKSEL     TRISC
    CLRF        TRISC                   ; CONFIGURA PORTA C COMO SAÍDA            
    
    BANKSEL     OPTION_REG
    MOVLW	     B'11101000'             ; HABILITA CLOCK EXTERNO
    MOVWF	     OPTION_REG              ; DEFINE OP��ES DE OPERA��O
                                        ; PRESCALER DE 1:1

    ; -- CONFIGURACAO DO PWM --
    BANKSEL     T1CON
	MOVLW       B'00001100'	        ; ATIVAR O PWM E COLOCA O DOIS BITS MENOS 
							            ; SIGNIFICATVOS DO PWM PARA 00
							            ; O PWM TEM 10 BITS ONDE OS OUTROS EST�O EM CCPR1L
	MOVWF	CCP1CON                   ; MODO DESLIGADO
	BSF		T1CON,0                   ; TMR1 LIGADO
;    MOVLW       B'00000001'             ; ATIVA TIMER1, CLOCK INTERNO (FOSC/4), SEM PRESCALER
;    MOVWF       T1CON
;    MOVLW       B'00001100'             ; CONFIGURA 2 LSB DO DUTY CYCLE DO PWM PARA 0
;                                        ; CONFIGURA TIMER 1 NO MODO PWM
;    MOVWF       CCP1CON
 
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
    MOVLW		  H'01'
    MOVWF       ADCON0                  ; CONFIGURA FOSC/2, LIGA CONVERSOR              
 
    BANKSEL     PWM_VAL
    MOVLW       D'128'                    ;
    MOVWF       PWM_VAL                 ; SETA PWM PARA 2^8

    CLRF        TMR0
    BCF         TFLAG
    MOVLW       DELAY_2S
    MOVWF       TMR0
    
    MOVLW       D'30'
    MOVWF      MINUTO

MAIN:
    BTFSS      PARTIDA
    GOTO       MAIN
    BSF        ON
    BANKSEL    INTCON
    MOVLW      B'10111000'
    MOVWF      INTCON
    GOTO       $

    END