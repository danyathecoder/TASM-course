.model tiny 
.code
.386
org 100h
start:
    jmp handlerInstall
    flagKill db 0
    flagSave db 0
    oldIRQ0 dd ?
    
    msgIntReturn db "Interrupts has been renewed", 0Dh,0Ah
    msgIntReturnSize equ 29
    msgSaved db "Screen was saved", 0Dh,0Ah
    msgSavedSize equ 18
    msgErrSave db "Error while saving screen", 0Dh,0Ah
    msgErrSaveSize equ 27
    flag db "flag"
    videoStart equ 0B800h
    screenEnd equ 0FA0h

    destFileName db "F000.txt", 0
    destFileCounter dw 0
    destFile dw 0

    wordSize dw 4
    videoPtr dw 0
    byteBuf db ?
    flagWrited db 0
    getWord db 126 dup('$')

    newIRQ0 proc far
        pushf
        call cs:dword ptr oldIRQ0
        pusha
        push ds
        push es
        push cs
        pop ds
;****************************************
        pusha
        mov ah, 01h                ;проверка нажатия клавиш
        int 16h
        mov dh, ah
        jz inputEnd
        mov ah, 02h
        int 16h
        and al, 4
        cmp al, 0
        jne checkS
        jmp inputEnd
    checkS:        
        cmp dh, 2Eh
        jne checkQ
        mov cs:flagSave, 1
        mov ah, 00h
        int 16h
        jmp inputEnd
    checkQ:
        cmp dh, 2Ch
        jne inputEnd
        mov cs:flagKill, 1
        mov ah, 00h
        int 16h
    inputEnd:
        popa
        
        pusha        
        mov ax, cs
        mov ds, ax

        mov flagWrited,0 
        cmp flagKill,1
        jne keepIRQ

        mov ah, 25h  ;устанавливаем адрес обработчика
        mov al, 09h    
        mov dx, word ptr cs:oldIRQ0      ;смещение обработчика
        mov ds, word ptr cs:oldIRQ0 + 2  ;сегмент обработчика
        int 21h

        mov ax, cs
        mov es, ax
        mov ah, 03h
        mov bh, 0
        int 10h
        
        mov ah, 13h
        mov al, 1
        mov bh, 0
        mov bl, 07h
        mov cx, msgIntReturnSize
        lea bp, msgIntReturn
        int 10h
       
        jmp oldIRQ0Mark
    keepIRQ:
        mov ax, videoStart
        mov es, ax
        mov videoPtr, 0
        
    loopFindWord:
        mov di, videoPtr
        lea si, getWord
    loopCheckWord:
        mov bl, es:di
        cmp bl, [si]
        jne nextSym
        add di, 2
        mov bx, videoPtr
        add bx, wordSize
        add bx, wordSize
        cmp di, bx
        je foundIt
qqq:        
        inc si
        jmp loopCheckWord

    foundIt:
        
        mov bl,es:di
        cmp bl,' '
            jne qqq
            
        sub di,wordSize
        sub di,wordSize
        sub di,2
        mov bl,es:di
        cmp bl,' '
            jne nextSym
            
        cmp flagSave, 1
        jne noHide
        call saveWord
        mov flagWrited,1
        mov cx, wordSize
        mov di, videoPtr

    noHide:        
        mov ax, wordSize
        add videoPtr, ax
        add videoPtr, ax
        jmp loopFindWordEnd      
    nextSym:                   ;ищем следующее совпадение
        add videoPtr, 2
    loopFindWordEnd:
        cmp videoPtr, screenEnd
        jb loopFindWord

    oldIRQ0Mark:
        mov flagSave, 0
        cmp flagWrited,1
        jne oldIRQ0End
        mov ax, cs
        mov es, ax
        mov ah, 03h
        mov bh, 0
        int 10h
        
        mov ah, 13h
        mov al, 1
        mov bh, 0
        mov bl, 07h
        mov cx, msgSavedSize           ;выводим сообщение о завершении поиска
        lea bp, msgSaved
        int 10h
    oldIRQ0End:
        popa        
                   
;****************************************        
        pop es
        pop ds
        popa

        iret
    newIRQ0 endp

    saveWord proc
        pusha
        mov ah, 34h
        int 21h
        cli
        
        mov al, es:bx   ;загружаем видеопамять со словом
        dec bx
        mov ah, es:bx
        cmp al, 0
        jne endPrintSCR
        cmp ah, 0
        jne endPrintSCR
        
        mov ax, videoStart ;начало памяти
        mov es, ax
        
        mov destFileCounter, 0
    openFindLoop:
        mov ax, destFileCounter
        mov dl, 100
        div dl
        add al, '0'
        mov destFileName + 1, al
        mov al, ah
        xor ah, ah
        mov dl, 10
        div dl
        add al, '0'
        add ah, '0'
        mov destFileName + 2, al   
        mov destFileName + 3, ah
        lea  dx, destFileName        ;формируем название файла
        xor cx, cx
        mov ah, 5Bh                  ;создаём новый файл
        int 21h
        jnc nameFound                ;если файл создан успешно
        inc destFileCounter
        cmp ax, 50h                  ;если такой файл существует
        je openFindLoop
        jmp endPrintSCR

    nameFound:
        mov destFile, ax             ;записываем идентификатор файла
        mov ax, videoPtr
        mov bl, 80
        div bl
        xor ah, ah
        inc al
        mul bl
        mov di, ax
        cmp di, 160  
        jb less1
        sub di, 240
        mov cx, 240
        jmp loopWriteSaved
    less1:
        cmp di, 80
        jb less2    
        sub di, 80
        mov cx, 160
    less2:
        mov cx, 160
        
    loopWriteSaved:
        mov bx, destFile
        mov ah, 40h
        push cx
        mov cl, es:di
        mov byteBuf, cl
        lea dx,  byteBuf
        mov cx, 1
        int 21h   
        pop cx 
        
        add di, 2
        cmp di, 4000
        jae loopWriteSavedEnd
        cmp cx, 161
        jne cmp81 

        mov bx, destFile
        mov ah, 40h
        push cx
        lea dx,  endl
        mov cx, 1
        int 21h
        pop cx   
cmp81:
        cmp cx, 81
        je NLWrite
        jmp woNL
        
    NLWrite:
        mov bx, destFile
        mov ah, 40h
        push cx
        mov byteBuf, 10
        mov dx, offset  byteBuf
        mov cx, 1
        int 21h   
        pop cx
    woNL:
        loop loopWriteSaved
        
    loopWriteSavedEnd:             ;закрываем файл
        mov bx, destFile
        xor ax,ax
        mov ah,3eh
        int 21h
        jb endPrintSCR
        mov dx,1
    endPrintSCR:
        sti
        popa
        ret
    saveWord endp

handlerInstall:
        mov si, 80h
        lea di, getWord     ;достаём из cmd искомое слово
        lodsb 
    loopSkip:
        lodsb
        cmp al, ' '
        je loopSkip      ;пропускаем пробелы
        cmp al, 0dh
        je endErrMark    ;выход если конец строки
        mov es:di, al    ;записываем символ в слово
        inc di           
    loopCL:
        lodsb
        cmp al, ' '
        je endOneArg
        cmp al, 0dh
        je endOneArg
        mov es:di, al    ;записываем остальные символы
        inc di
        jmp loopCL
    endOneArg:
        sub di, offset getWord    ;из конца слова отнимаем начало
        mov wordSize, di       ;записываем длину слова
        
        mov ah, 35h            ;получаем адрес обработчика
        mov al, 09h            ;номер вектора обработчика от клавиатуры
        int 21h
        mov word ptr oldIRQ0, bx     ;смещение обработчика
        mov word ptr oldIRQ0 + 2, es ;сегмент обработчика

        lea di,   flag      
        lea si,   flag
        mov cx, 4
        repe cmpsb              ;проверяем 
        je loaded
        mov ah, 25h             ;устанавливаем адрес обработчика
        mov al, 09h             ;клавиатура
        mov dx, offset newIRQ0  ;смещение обработчика в сегменте
        int 21h
        mov ah, 09h
        mov dx, offset msgControls
        int 21h   
        mov ax, 3100h                                ;оставляем программу резидентной
        mov dx, (handlerInstall-start + 10Fh) / 16   ;размер резидентной программы в параграфе
        int 21h

    endErrMark:
        jmp handlerInstallEnd
        loaded:
        mov ah, 09h
        mov dx, offset msgAlready
        int 21h  
    handlerInstallEnd:
        .exit                  
msgErrArgs db "One argument required. Proper arguments example:command requiredWord", '$'
msgControls db "Ctrl+C - find word, Ctrl+Z - return interrupts",0Dh,0Ah,'$'
msgAlready db "Programm was already launched ", '$'
endl db 10, 13, '$'          
end start