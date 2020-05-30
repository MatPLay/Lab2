    .model small
    .stack 100h  
    .data    
buffer db ?
file_name db ?
open_file_error db "open file error",0Ah,0Dh,"$"  
read_file_error db "read file error",0Ah,0Dh,"$"
program_start_message db "program starts",0Ah,0Dh,"$"    
string_length dw 0h                   
empty_strings dw 0h    
empty_strings_message db " empty string(s) in file",0Ah,0Dh,"$"
empty_cmd_message db "empty command line",0Ah,0Dh,"$"
    .code      
    
hex_to_str proc
    pusha   
    push 24h
    mov bx,0Ah      

translate_loop:
    xor dx,dx              
    div bx 
    push dx
    xor dx,dx
    cmp ax,0h
    je _end 
    jmp translate_loop   
         
_end:
    mov ah,2h                     
        
write_number:
    pop dx
    cmp dx,24h   
    je _end_
    add dx,30h 
    int 21h             
    jmp write_number   
        
_end_:            
    popa
    ret  
hex_to_str endp 
    
start:  
    mov ax,@data
    mov ds,ax   
    lea dx,program_start_message
    mov ah,9h
    int 21h        
    mov di,80h
    mov cl,es:[di]
    cmp cl,1h
    jle empty_cmd               
    mov cx,-1h          
    mov di,81h
    mov al,' '
    repe scasb
    dec di         
    mov bx,0h   
    
get_file_name:
    cmp es:[di],0Dh
    je set_string_end
    mov al,es:[di]
    mov file_name[bx],al
    inc bx    
    inc di
    jmp get_file_name
    
set_string_end:
    mov file_name[bx],0h   
    mov ah,3Dh
    mov al,0h        
    lea dx,file_name
    int 21h   
    jc open_file_error_label   
    mov bx,ax       

file_read:
    mov cx,1h
    lea dx,buffer
    mov ah,3Fh
    int 21h
    jc read_file_error_label    
    cmp buffer,0Ah
    je continue     
    cmp buffer,0Dh
    jne increase_string_length
    je check_empty    
    
increase_string_length:
    inc string_length
    jmp continue

check_empty:
    cmp string_length,0h
    je empty 
    mov string_length,0h
    jmp continue 
    
empty:
    inc empty_strings
    mov string_length,0h

continue:    
    cmp ax,0h
    jne file_read 
    mov ah,3Eh
    int 21h
    jmp print_empty_strings_message
    
open_file_error_label:
    lea dx,open_file_error
    mov ah,9h
    int 21h
    jmp exit   
    
read_file_error_label:
    lea dx,read_file_error
    mov ah,9h
    int 21h 
    mov ah,3Eh
    int 21h
    jmp exit   

empty_cmd:
    mov ax,@data
    mov ds,ax 
    lea dx,empty_cmd_message
    mov ah,9h
    int 21h 
    jmp exit

print_empty_strings_message:         
    mov ax,empty_strings
    call hex_to_str 
    lea dx,empty_strings_message
    mov ah,9h
    int 21h  

exit:    
    mov ax,4C00h
    int 21h    
    end start