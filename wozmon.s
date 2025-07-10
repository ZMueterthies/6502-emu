.org $ff00

; ----------------
; Page 0 Variables
; ----------------
XAML    = $24           ; Low-order 'examine index'(most recent memory location) byte      
XAMH    = $25           ; High-order 'examine index'(most recent memory location) byte
STL     = $26           ; Low-order 'store index' byte
STH     = $27           ; High-order 'store index' byte
L       = $28           ; Low-order hex input byte
H       = $29           ; High-order hex input byte
YSAV    = $2A           ; Temporary save location for Y register
MODE    = $2B           ; $00=XAM, $7B=STOR, $AE=BLOK XAM

; ----------------
; Other Variables
; ----------------
IN      = $0200         ; Input buffer, goes to $027F
KBD     = $D010         ; Keyboard data.
KBDCR   = $D011         ; Keyboard control register.
DSP     = $D012         ; Display data.
DSPCR   = $D013         ; Display control register.

RESET:
        CLD             ; Clear decimal arithmetic mode flag.
        CLI             ; Clear interrupt disable flag.
        LDY #$7F        ; Mask for DSP data direction register.
        STY DSP         ; Set it up.
        LDA #$A7        ; KBD and DSP control register mask.
        STA KBDCR       ; Enable interrupts, set CA1, CB1, for
        STA DSPCR       ;  positive edge sense/output mode.
NOTCR: 
        CMP #$DF        ; Backspace?
        BEQ BACKSPACE   ;  Yes.
        CMP #$9B        ; ESC?
        BEQ ESCAPE      ;  Yes.
        INY             ; Advance text index.
        BPL NEXTCHAR    ; Auto ESC if > 127.
ESCAPE:
        LDA #$DC        ; Load '/' into accumulator.
        JSR ECHO        ; Jump to subroutine ECHO to print '/'
GETLINE:
        LDA #$8D        ; Load CR into accumulator.
        JSR ECHO        ; Jump to subroutine ECHO to print CR.
        LDY #$01        ; Initialize text index.
BACKSPACE:
        DEY             ; Decrement text index
        BMI GETLINE     ; Beyond start of line, reinitialize
NEXTCHAR:
        LDA KBDCR       ; Load keybaord control register into accumulator. Key ready?
        BPL NEXTCHAR    ;  No, loop until ready
        LDA KBD         ; Load keyboard data into accumulator. B7 should be '1'.
        STA IN,Y        ; Store accumulator into the current text buffer position (Input buffer + Y).
        JSR ECHO        ; Jump to subroutine ECHO to print character.
        CMP #$8D        ; CR?
        BNE NOTCR       ;  No.
        LDY #SFF        ; Reset text index.
        LDA #$00        ; F or XAM mode.
        TAX             ; Set X to 0
ECHO:
        BIT DSP         ; DA(Display Available) bit (B7) cleared yet?
        BMI ECHO        ;  No, loop until ready.
        STA DSP         ; Output character. Sets DA.
        RTA             ; Return from subroutine.