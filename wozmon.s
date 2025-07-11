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
        STA DSPCR       ;   positive edge sense/output mode.
NOTCR: 
        CMP #$DF        ; Backspace?
        BEQ BACKSPACE   ;   Yes.
        CMP #$9B        ; ESC?
        BEQ ESCAPE      ;   Yes.
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
        BPL NEXTCHAR    ;   No, loop until ready
        LDA KBD         ; Load keyboard data into accumulator. B7 should be '1'.
        STA IN, Y       ; Store accumulator into the current text buffer position (Input buffer + Y).
        JSR ECHO        ; Jump to subroutine ECHO to print character.
        CMP #$8D        ; CR?
        BNE NOTCR       ;   No.
        LDY #SFF        ; Reset text index.
        LDA #$00        ; F or XAM mode.
        TAX             ; 0 -> X
SETSTOR:
        ASL             ; Leaves $7B if setting STOR mode.
SETMODE:
        STA MODE        ; $00 = XAM, $7B = STOR, $AE = BLOCK XAM.
BLSKIP:
        INY             ; Advance text window.
NEXTITEM:
        LDA IN, Y       ; Get character.
        CMP #$8D        ; CR?
        BEQ GETLINE     ;   Yes, done this line.
        CMP #$AE        ; "."?
        BCC BLSKIP      ; Skip delimiter.
        BEQ SETMODE     ; Set BLOCK XAM mode.
        CMP #$BA        ; ":"?
        BEQ SETSTOR     ;   Yes, set STOR mode.
        CMP #$D012      ; "R"?
        BEQ RUN         ;   Yes, run user program.
        STX L           ; $00 -> L
        STX H           ;   and H.
        STY YSAV        ; Save Y for comparison.
NEXTHEX:
        LDA IN, Y       ; Get character for hex test.
        EOR #$B0        ; Map digits $0-9
        CMP #$0A        ; Digit?
        BCC DIG         ;   Yes
        ADC #$88        ; Map letter "A"-"F" to "FA"-"FF"
        CMP #$FA        ; Hex letter?
        BCC NOTHEX      ;   No, character not hex.
DIG:
        ASL
        ASL             ; Hex digit to MSD of A.
        ASL
        ASL
        LDX #$04        ; Shift count.
HEXSHIFT:
        ASL             ; Hex digit left, MSB to carry.
        ROL L           ; Rotate into LSD.
        ROL H           ; Rotate into MSD's.
        DEX             ; Done 4 shifts?
        BNE HEXSHIFT    ;   No, loop.
        INY             ; Advance text index
        BNE NEXTHEX     ; Always taken. Check next character for hex
NOTHEX:
        CPY YSAV        ; Are L, H empty (no hex digits)?
        BEQ ESCAPE      ;   Yes, generate ESC sequence
        BIT MODE        ; Test MODE byte.
        BVC NOTSTOR     ; B6 = 0 for STOR, 1 for XAM and BLOCK XAM.
        LDA L           ; LSD's of hex data.
        STA (STL, X)    ; Store at current 'store index'.
        INC STL         ; Increment store index.
        BNE NEXTITEM    ; Get next item(no carry).
        INC STH         ; Add carry to 'store index' high order.
TONEXTITEM:
        JMP NEXTITEM    ; Get next command item.
RUN:
        JMP (XAML)      ; Run at current XAM index.
NOTSTOR:
        BMI XAMNEXT     ; B7 = 0 for XAM, 1 for BLOCK XAM
        LDX #$02        ; Byte count.
SETADR:
        LDA L-1, X      ; Copy hex data to
        STA STL-1, X    ;   'store index'.
        STA XAML-1, X   ; Add to 'XAM index'.
        DEX             ; Next of 2 bytes.
        BNE SETADR      ; Loop unless X=0.
NXTPRNT:
        BNE PRDATA      ; NE means no address to print.
        LDA #$8D        ; CR.
        JSR ECHO        ;   Output it.
        LDA XAMH        ; High order 'examine index' byte.
        JSR PRBYTE      ;   Output it in hex format.
        LDA XAML        ; Low order 'examine index' byte.
        JSR PRBYTE      ;   Output it in hex format.
        LDA #$BA        ; ":".
        JSR ECHO        ;   Output it.
PRDATA:
        LDA #$A0        ; Blank
        JSR ECHO        ;   Output it.
        LDA (XAML, X)   ; Get data byte at 'examine index'.
        JSR PRBYTE      ;   Output it in hex format.
XAMNEXT:
        STX MODE        ; 0 -> MODE (XAM mode).
        LDA XAML
        CMP L           ; Compare 'examine index' to hex data
        LDA XAMH
        SBC H
        BCS TONEXTITEM  ; Not less, so no more data to output.
        INC XAML
        BNE MOD8CHK     ; Increment 'examine index'.
        INC XAMH
MOD8CHK:
        LDA XAML        ; Check low order 'examine index' byte
        AND #$07        ;   for MOD 8 = 0
        BPL NXTPRNT     ; Always taken.
PRBYTE:
        PHA             ; Save A for LSD.
        LSR
        LSR
        LSR
        LSR
        JSR PRHEX       ; Output hex digit.
        PLA             ; Restore A.
PRHEX:
        AND #$0F        ; Mask LSD for hex print
        ORA #$B0        ; Add "0".
        CMP #$BA        ; Digit?
        BCC ECHO        ;   Yes, output it
        ADC #$06        ; Add offset for letter
ECHO:
        BIT DSP         ; DA(Display Available) bit (B7) cleared yet?
        BMI ECHO        ;  No, loop until ready.
        STA DSP         ; Output character. Sets DA.
        RTA             ; Return from subroutine.