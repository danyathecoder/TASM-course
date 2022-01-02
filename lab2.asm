.model small
.stack 100h

.data 

maxLength equ 200
strPointer db maxLength
stringLen db ?
string db maxLength dup(?)

searchStrPointer db maxLength
searchLen db ?
searchStr db maxLength dup(?)

replaceStrPointer db maxLength
replaceLen db ?
replaceStr db maxLength dup(?)

enter_msg db "Enter string: $"
enter_subStr1 db "Enter substring to replace: $"
enter_subStr2 db "Enter word: $"
nextString db 0ah, 0dh, '$' 

errorStr db "Error!$"

.code

macro input str
    mov ah, 0Ah
    lea dx, str
    mov bx, dx
    int 21h
    
    xor ax, ax
    mov al, [str + 1]
    add bx, ax
    mov [bx + 2], '$' 
endm           

macro output str
    lea dx, str
    mov ah, 9
    int 21h
endm

macro nextStr 
    lea dx, nextString
    mov ah, 9
    int 21h
endm

start:
    mov ax, @data
    mov ds, ax
    mov es, ax
    
    output enter_msg
    input strPointer
    nextStr

enter_search:
    output enter_subStr1
    input searchStrPointer
    nextStr
    
    mov al, searchLen
    cmp al, stringLen
    ja enter_search

enter_replace:
    output enter_subStr2
    input replaceStrPointer
    nextStr
    
    lea si, string
    lea di, searchStr

    mov bx, si
    xor dx, dx
    
compare:
    cmp [si], '$'
    je finish
    
    cmp [si], ' '
    je set_first_index
    
    inc si
    
    jmp find_second_index

found_match:
    inc si
    lea di, searchStr
    jmp compare     
    
start_searching:
    push di
    mov di, si
    pop si
    
    mov cx, dx
    sub cx, bx
    
    mov al, [si]
     
    mov di, bx 
    
    jmp continue_searching
    
continue_searching:
    cld
    repne scasb
    
    push di
    mov di, si
    pop si
    
    je check_end
    
    lea di, searchStr
    
    jmp compare    

check_end:
    inc di
    cmp [di], '$'
    je found
    jmp start_searching

found:
    sub dx, bx
    cmp dl, replaceLen
    push di
    push bx
    ja shift_left
    jb shift_right
    sub dl, replaceLen
    jmp replace

set_first_index:
    inc si
    cmp [si], ' '
    je compare  
    cmp [si], '$'    
    je finish
    mov bx, si
    jmp find_second_index
    
find_second_index:
    cmp [si], ' '
    je set_second_index
    cmp [si], '$'
    je set_second_index
    inc si
    jmp find_second_index

set_second_index:
    mov dx, si
    jmp start_searching

shift_left:
    push di
    push bx
    
    add bx, dx
    mov si, bx
    sub dl, replaceLen
    mov di, si
    sub di, dx;
    xor cx, cx
    mov cl, stringLen
    add cl, 2
    sub cx, di
    sub stringLen, dl  
    
    cld
    rep movsb
    
    pop bx
    jmp replace
    
    output string
shift_right:
    lea cx, string
    add cl, stringLen
    mov si, cx
    add bx, dx
    sub cx, bx
    inc cl
    sub dl, replaceLen
    neg dl
    add stringLen, dl
    
    mov ah, stringLen
    cmp ah, maxLength
    ja error
    
    mov di, si
    add di, dx
    
    std
    rep movsb
    
    pop bx
    
    jmp replace

replace:
    cld
    mov di, bx
    lea si, replaceStr
    xor cx, cx
    mov cl, replaceLen
    push cx
    
    rep movsb
    
    
    mov si, di
    lea di, searchStr
    jmp compare
    
error:
    output errorStr
    jmp exit
      
finish:
    output string
    jmp exit
    
exit:
    mov ax, 4c00h
    int 21h
    
end start