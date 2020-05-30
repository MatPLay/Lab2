.model small
.stack 100h
.data

buf_size        equ 255

buf_data        db buf_size, ?
buf             db buf_size dup (?)
sign            db ?
base_sys        db ?
new_sys         db ?
error_message   db "error", 0Dh, 0Ah, '$'
new_line        db 0Dh, 0Ah, '$'

.code
jmp start

get_small_num proc; output: dx - number, c set on error
    clc
    cld
    push ax
    push bx
    push cx
    push si

    mov ah, 0Ah
    mov dx, offset buf_data
    int 21h

    xor ah, ah
    mov al, [buf_data + 1]
    cmp al, 0
    je get_small_num_error
    mov si, offset buf
    mov cx, ax

    xor bx, bx

    get_small_num_loop:
        lodsb
        cmp al, '0'
        jb get_small_num_error
        cmp al, '9'
        ja get_small_num_error

        sub al, '0'

        mov bl, al
        mov al, dl
        mov ah, 0Ah
        mul ah
        add al, bl
        mov dl, al
        cmp dl, 16
        ja get_small_num_error

        loop get_small_num_loop

    cmp dl, 2
    jb get_small_num_error
    clc
    jmp get_small_num_end

    get_small_num_error:
    stc
    jmp get_small_num_end

    get_small_num_end:
    pop si
    pop cx
    pop bx
    pop ax
    ret
endp

to_str proc; ax - number, cx - base
    pushf
    push ax
    push cx
    push dx
    push di
    push si

    cmp byte ptr sign, 0
    je to_str_pos
    mov dx, -1
    imul dx
    mov di, offset buf
    mov byte ptr [di], '-'

    to_str_pos:

    mov di, offset buf + buf_size - 1

    std
    push ax
    mov al, '$'
    stosb
    pop ax
    

    xor si, si
    inc si

    to_str_loop:
        xor dx, dx
        div cx
        call store_digit
        inc si
        cmp ax, 0
        ja to_str_loop

    cld
    mov cx, si
    mov si, di
    inc si
    mov di, offset buf
    cmp sign, 0
    je to_str_fine
    inc di
    to_str_fine:
    rep movsb

    to_str_end:
    pop si
    pop di
    pop dx
    pop cx
    pop ax
    popf
    ret
endp

store_digit proc; dx - digit
    push dx
    push ax
    cmp dx, 9
    jbe store_digit_decimal

    sub dx, 10
    add dx, 'A'
    mov ax, dx
    stosb
    jmp store_digit_end

    store_digit_decimal:
    add dx, '0'
    mov ax, dx
    stosb

    store_digit_end:
    pop ax
    pop dx
    ret
endp

get_num proc; cx - base; output: dx - number, c set on error
    clc
    push ax
    push cx
    push si
    push bx

    mov bx, cx
    mov ah, 0Ah
    mov dx, offset buf_data
    int 21h

    xor ah, ah
    mov al, [buf_data + 1]
    cmp al, 0
    je get_num_error
    mov si, offset buf
    mov cx, ax

    xor dx, dx

    cmp byte ptr [si], '-'
    je get_num_neg

    get_num_pos:
    mov sign, 0
    cmp byte ptr [si], '+'
    jne get_num_loop
    inc si
    dec cx
    cmp cx, 0
    je get_num_error
    get_num_neg:
    mov sign, 1
    inc si
    dec cx
    cmp cx, 0
    je get_num_error

    get_num_loop:
        lodsb

        cmp al, '0'
        jb get_num_loop_hex
        cmp al, '9'
        ja get_num_loop_hex
        jmp get_num_loop_dec

        get_num_loop_dec:
        sub al, '0'
        jmp get_num_loop_fine

        get_num_loop_hex:
        cmp al, 'A'
        jb get_num_error
        cmp al, 'F'
        ja get_num_error
        sub al, 'A'
        add al, 10
        jmp get_num_loop_fine

        get_num_loop_fine:
        push cx
        mov cx, bx
        call add_digit
        pop cx
        jc get_num_error

        loop get_num_loop

    clc
    jmp get_num_end
    get_num_error:
    stc
    jmp get_num_end
    get_num_end:
    pop bx
    pop si
    pop cx
    pop ax
    ret
endp

add_digit proc; dx - number, al - to_add, cl - base; output: dx - new number, c set on error
    cmp al, cl
    jae add_digit_error

    cmp sign, 0
    je add_digit_0
    call add_digit_neg
    jc add_digit_error
    clc
    jmp add_digit_end

    add_digit_0:
    call add_digit_pos
    jc add_digit_error
    clc
    jmp add_digit_end

    add_digit_error:
    stc
    add_digit_end:
    ret
endp

add_digit_neg proc; dx - number, al - to_add, cl - base; output: dx - new number, c set on error    
    push ax
    push bx
    push cx
    push si

    
    cmp dx, 0
    je add_digit_neg_0

    xor ch, ch
    mov si, cx; si - base
    mov bx, ax; bx - to add
    mov ax, dx; ax - old number
    imul cx; dx:ax - new value
    cmp dx, 0FFFFh
    jne add_digit_neg_error
    mov cx, ax; cx - new lower
    and cx, 8000h
    cmp cx, 8000h
    jne add_digit_neg_error
    mov cx, 08000h
    add cx, bx
    cmp ax, cx
    jb add_digit_neg_error
    sub ax, bx
    mov dx, ax
    clc
    jmp add_digit_neg_end

    add_digit_neg_0:
    mov ah, -1
    imul ah
    mov dx, ax
    clc
    jmp add_digit_neg_end

    add_digit_neg_error:
    stc
    jmp add_digit_neg_end

    add_digit_neg_end:
    pop si
    pop cx
    pop bx
    pop ax
    ret
endp

add_digit_pos proc; dx - number, al - to_add, cx - base; output: dx - new number, c set on error
    push ax
    push bx
    push cx
    push si

    
    cmp dx, 0
    je add_digit_pos_0

    xor ch, ch
    mov si, cx; si - base
    mov bx, ax; bx - to add
    mov ax, dx; ax - old number
    imul cx; dx:ax - new value
    cmp dx, 0
    jne add_digit_pos_error
    mov cx, ax; cx - new lower
    and cx, 8000h
    cmp cx, 8000h
    je add_digit_pos_error
    mov cx, 7FFFh
    sub cx, bx
    cmp ax, cx
    ja add_digit_pos_error
    add ax, bx
    mov dx, ax
    clc
    jmp add_digit_pos_end


    add_digit_pos_0:
    xor ah, ah
    mov dx, ax
    clc
    jmp add_digit_pos_end

    add_digit_pos_error:
    stc
    jmp add_digit_pos_end

    add_digit_pos_end:
    pop si
    pop cx
    pop bx
    pop ax
    ret
endp

endl macro
    push ax
    push dx
    mov ah, 09h
    mov dx, offset new_line
    int 21h
    pop dx
    pop ax
endm


start:
    mov ax, @data
    mov ds, ax
    mov es, ax

    call get_small_num
    jc error
    mov base_sys, dl
    endl
    call get_small_num
    jc error
    mov new_sys, dl
    endl
    xor ch, ch
    mov cl, base_sys
    call get_num
    jc error
    endl
    mov ax, dx
    xor ch, ch
    mov cl, new_sys
    call to_str
    mov ah, 09h
    mov dx, offset buf
    int 21h
    endl

    jmp _end
error:
    endl
    mov ah, 09h
    mov dx, offset error_message
    int 21h
_end:
    mov ax, 4C00h
    int 21h

end start