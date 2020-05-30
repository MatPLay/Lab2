.model tiny
.code
org 100h

start:
jmp beginning

max_path_size               equ 124

buf                         db ?
exec_file_path              db max_path_size dup (0), 0
file_not_found              db "file not found", 0Ah, 0Dh, '$'
path_not_found              db "path not found", 0Ah, 0Dh, '$'
access_denied               db "access denied", 0Ah, 0Dh, '$'
error_message               db "wrong command line argument format", 0Dh, 0Ah, "correct format:", 0Dh, 0Ah, "number_of_repeats[1-255] filename", 0Dh, 0Ah, '$'
couldnt_resize_memory       db "couldn't resize memory", 0Ah, 0Dh, '$'
failed_to_start             db "failed to launch file", 0Ah, 0Dh, '$'


parse_command_line proc; dx - number of repeats, exec_file_path contains program path
    push bx
    push cx
    xor ah, ah
    mov al, byte ptr ds:[80h]
    cmp al, 0
    je parce_command_line_error

    xor ch, ch
    mov cl, al
    mov di, 81h
    call get_number
    jc parce_command_line_error
    mov dx, bx
    call store_file_name
    jc parce_command_line_error

    jmp parce_command_line_end
    parce_command_line_error:
    stc
    parce_command_line_end:
    pop cx
    pop bx
    ret
endp

store_file_name proc; 
    push ax
    push si
    mov al, ' '
    repe scasb
    cmp cx, 0
    je store_file_name_start_error
    dec di
    inc cx
    push di
    mov si, di
    mov di, offset exec_file_path
    rep movsb
    jmp store_file_name_end
    store_file_name_start_error:
    push di
    store_file_name_error:
    stc
    store_file_name_end:
    pop di
    pop si
    pop ax
    ret
endp

get_number proc; di - string, cx - number of chars, bx - result
    push ax
    push dx
    push si
    
    xor bx, bx
    mov al, ' '
    repe scasb
    cmp cx, 0
    je get_number_error
    dec di
    mov si, di
    get_number_loop:
        xor ah, ah
        lodsb
        cmp al, ' '
        je get_number_post
        cmp al, '0'
        jb get_number_error
        cmp al, '9'
        ja get_number_error
        sub al, '0'; bx - result, al - to add
        mov dx, ax; dx - to add
        mov ax, bx; ax - result
        mov bx, dx
        push cx
        mov cx, 10
        mul cx
        pop cx
        add ax, bx; ax - new result
        mov bx, ax; bx - result
        cmp bx, 255
        ja get_number_error
        loop get_number_loop

    get_number_post:
    cmp bx, 0
    je get_number_error
    jmp get_number_end

    get_number_error:
    stc
    get_number_end:
    mov di, si
    pop si
    pop dx
    pop ax
    dec di
    inc cx
    ret
endp

shrink_memory macro
    push ax
    push bx
    mov sp, length_of_program + 100h + 200h
    mov ax, length_of_program + 100h + 200h
    shr ax, 4
    inc ax
    mov bx, ax
    mov ah, 4Ah
    int 21h
    pop bx
    pop ax
endm


beginning:
    call parse_command_line
    jc error_my

prep_for_start:
    shrink_memory
    jc error1
    jmp init_EPB

init_EPB:

    mov ax, cs
    mov word ptr EPB + 4, ax
    mov word ptr EPB + 8, ax
    mov word ptr EPB + 0Ch, ax
    
    mov ax, 04B00h
    mov cx, dx
    mov dx, offset exec_file_path
    mov bx, offset EPB
    startup_loop:
    int 21h
    jc error
    loop startup_loop

    jmp _end

error_my:
    mov dx, offset error_message
    mov ah, 9h
    int 21h
    jmp _end
    error1:
    mov dx, offset couldnt_resize_memory 
    mov ah, 9h
    int 21h
    jmp _end
error:
    push ax
    mov dx, offset failed_to_start
    mov ah, 9h
    int 21h
    pop ax
    cmp ax, 02h
    je error_1
    cmp ax, 05h
    je error_2
    jmp error_3
error_1:
    mov dx, offset file_not_found
    jmp log_error
error_2:
    mov dx, offset access_denied
    jmp log_error
error_3:
    jmp _end
log_error:
    mov ah, 9h
    int 21h

_end:
    int 20h

EPB                 dw 0000
                    dw offset commandline, 0
                    dw 005Ch, 006Ch

commandline         db 124
command_text        db 125 dup (?)
command_buffer      db 122


length_of_program   equ $-start

end start