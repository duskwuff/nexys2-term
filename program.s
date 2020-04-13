_start:
    li  r15, 4000   ; stack, top of memory
    li  r13, @globals

    li  r1, 7400
    bl  cls

    li  r1, @beware_i_live
    li  r2, 1000
    bl  putstring

    li  r1, 8108
    st  r1, 0(r13)

main_loop:
    bl  getchar
    bl  putchar
    li  r2, 7000    ; apply color to char
    or  r1, r2
    ld  r2, 0(r13)  ; get cursor loc
    st  r1, 0(r2)   ; store character
    inc r2
    inc r2
    st  r2, 0(r13)  ; save cursor loc
    b main_loop
.constpool


getchar:
    mflr r14
    li  r8, ff00
getchar_loop:
    ld  r1, 2(r8)   ; rxwaiting
    cmp r0, r1
    beq getchar_loop
    ld  r1, 0(r8)
    st  r0, 2(r8)   ; clear rxwaiting
    mtpc r14

putchar:
    mflr r14
    li  r8, ff00
putchar_loop:
    ld r2, 4(r8)    ; txready
    cmp r0, r2
    beq putchar_loop
    st  r1, 0(r8)
    mtpc r14
.constpool


delay:
    mflr r14
    li  r1, #40
delay_loop:
    li  r2, 0
delay_inner_loop:
    dec r2
    bne delay_inner_loop
    dec r1
    bne delay_loop
    mtpc r14
.constpool


; r1 = color mask
cls:
    mflr r14
    li  r8, 8000    ; vga base
    li  r9, #3960   ; 132 x 30
cls_loop:
    st  r1, 0(r8)
    inc r8
    inc r8
    dec r9
    bne cls_loop
    mtpc r14
.constpool


; r1 = address of string
; r2 = color mask
putstring:
    mflr r14
    li  r8, 8000
    ; FIXME: ignores cursor pos and assumes we always start at 0,0
    b putstring_ld
putstring_loop:
    or  r3, r2
    st  r3, 0(r8)
    inc r8
    inc r8
    inc r1
putstring_ld:
    ldb r3, 0(r1)
    cmp r0, r3
    bne putstring_loop
putstring_exit:
    mtpc r14
.constpool


globals:
    dw  0000        ; 0(r13) - cursor col
    dw  0000        ; 2(r13) - cursor row


beware_i_live:
    asciiz "BEWARE, I LIVE!!! "
