.model small

.stack 100h

.data    

iSymDX                dw  0
iSymCX                dw  0
jSymDX                dw  0
jSymCX                dw  0

tempDX                dw  0
flagTemp              dw  0

maxCMDSize equ 127
cmd_size              db  ?
cmd_text              db  maxCMDSize + 2 dup(0)
sourcePath            db  129 dup (0) 

two                   db 2
extension             db "txt"       
pointSym              db '.'
iBuf                  db  0
jBuf                  db  0
buf                   db  0                      
sourceID              dw  0
                                                                      
newLineSymbol         equ 0Dh
returnSymbol          equ 0Ah                           
endl                  equ 0

newl                  db 0Dh
cret                  db 0Ah

startProcessing       db "Processing started",                                                '$'                      
startText             db  "Program is started",                                               '$'
badCMDArgsMessage     db  "Bad command-line arguments.",                                      '$'
badSourceText         db  "Open error",                                                       '$'    
fileNotFoundText      db  "File not found",                                                   '$'
endText               db  0Dh,0Ah,"Program is ended",                                         '$'
errorReadSourceText   db  "Error reading from source file",                                   '$'

.code

println MACRO info          ;
	push ax                 ;
	push dx                 ;
                            ;
	mov ah, 09h             ; ������� ������ 
	lea dx, info            ; �������� � dx �������� ���������� ���������
	int 21h                 ; ����� ����������� ��� ���������� ������
                            ;
	mov dl, 0Ah             ; ������ �������� �� ����� ������
	mov ah, 02h             ; ������� ������ �������
	int 21h                 ; ����� ����������
                            ;
	mov dl, 0Dh             ; ������ �������� � ������ ������   
	mov ah, 02h             ;
	int 21h                 ;     
                            ;
	pop dx                  ;
	pop ax                  ;
ENDM


incrementTempPos MACRO num          ;�������������� tempDX, ���� ��������� ������������ ��������� ���
    add tempDX, num
    jo overflowTempPos
    jmp endIncrementTempPos
     
overflowTempPos:
    inc flagTemp
    mov tempDX, 1
    jmp endIncrementTempPos
    
endIncrementTempPos:            
endm 

decrementEndPos proc
    push ax
    
    mov ax, jSymDX
    dec ax
    cmp ax, 0
    je minusPos
    mov jSymDX, ax
    jmp endDecrement 
    
minusPos:
    dec jSymCX
    mov jSymDX, 32767 
          
endDecrement:
    
    pop ax
    ret
endp    

incrementStartPos proc          ; �������������� iSymDX, ���� ��������� ������������ ��������� ���
    push ax
    
    mov ax, iSymDX
    inc ax
    jo overflow
    mov iSymDX, ax
    jmp endIncrement
     
overflow:
    inc iSymCX
    mov iSymDX, 1
    
endIncrement:

    pop ax
    ret    
endp    

  
        
fseekCurrent MACRO settingPos
    push ax                  
	push cx                     
	push dx
	
	mov ah, 42h                 ; ���������� � ah ��� 42h - �-��� DOS ��������� ��������� �����
	mov al, 1                   ; 1 - ����������� ��������� �� ������� �������
	mov cx, 0                   ; �������� cx, 
	mov dx, settingPos	        ; �������� dx, �.� ��������� ��������� �� 0 �������� �� ������ ����� (cx*65536)+dx 
	int 21h                     ; �������� ���������� DOS ��� ���������� �������   
                             
	pop dx                      
	pop cx                      
	pop ax               
ENDM

fseek MACRO fseekPos
    push ax                     
	push cx                     
	push dx
	
	mov ah, 42h                 ; ���������� � ah ��� 42h - �-��� DOS ��������� ��������� �����
	mov al, 0 			        ; 0 - ��� ����������� ��������� � ������ ����� 
	mov cx, 0                   ; �������� cx, 
	mov dx, fseekPos            ; �������� dx, �.� ��������� ��������� �� 0 �������� �� ������ ����� (cx*65536)+dx 
	int 21h                     ; �������� ���������� DOS ��� ���������� �������   
                                
	pop dx                      
	pop cx                      
	pop ax    
           
ENDM

main:
	mov ax, @data           ; ��������� ������
	mov es, ax              ;
                            ;
	xor ch, ch              ; �������� ch
	mov cl, ds:[80h]		; ���������� �������� ������, ���������� ����� ��������� ������
	dec cl                  ; ��������� �������� ���������� �������� � ������ �� 1, �.�. ������ ������ ������
	mov bl, cl                
	
	mov si, 82h             ; �������� �� ��������, ���������� ����� ��������� ������
	lea di, cmd_text        
		
	rep movsb               ; �������� � ������ ������� ES:DI ���� �� ������ DS:SI
	
	mov ds, ax              ; ��������� � ds ������  
	mov cmd_size, bl        
	
    mov cl, bl
	lea si, cmd_text
	lea di, sourcePath

	rep movsb
	                        
	println startText       ; ����� ������ � ������ ������ ���������
                            
	call parseCMD           ; ����� ��������� �������� ��������� ������
	cmp ax, 0               
	jne endMain				; ���� ax != 0, �.�. ��� ��������� ��������� ��������� ������ - ��������� ���������
                            
	call openFile           ; �������� ���������, ������� ��������� ����, ���������� ����� ��������� ������ � ���� ��� ������ ����������
	cmp ax, 0               
	jne endMain				
                            
	call reverseAllStrings             ; ������ ���� �����
	call reverseFile                   ; ������ ����� �����
	call reverseCRETAndNewLine         ; ������ ������� cret � newl, �.�. ��� ������� ����� ��� ���� ����������� � �� ������ ����
                            
endMain:                    
	println endText             ; ������� ��������� � ���������� ������ ���������
                            
	mov ah, 4Ch                 ; ��������� � ah ��� ������� ���������� ������
	int 21h                     ; ����� ���������� DOS ��� �� ����������  
	         
parseCMD proc
    xor ax, ax
    xor cx, cx
    
    cmp cmd_size, 0             ; ���� �������� �� ��� �������, �� ��������� � notFound 
    je notFound
    
    mov cl, cmd_size
    
    lea di, cmd_text
    mov al, cmd_size
    add di, ax
    dec di
    
findPoint:                      ; ���� ����� � ����� �����, �.�. ����� �� ���� ���������� �����
    mov al, '.'
    mov bl, [di]
    cmp al, bl
    je pointFound
    dec di
    loop findPoint
    
notFound:                       ; ���� ����� �� ������� ������� badCMDArgsMessage � ��������� ���������
    println badCMDArgsMessage
    mov ax, 1
    ret
    
pointFound:                     ; ���������� �������� ������ ���� ����� 3, �.�. "txt", ���� ������� �� ����� => ���� �� ��������
    mov al, cmd_size
    sub ax, cx
    cmp ax, 3
     
    jne notFound
     
    xor ax, ax
    lea di, cmd_text
    lea si, extension
    add di, cx
    
    mov cx, 3
    
    repe cmpsb                  ; ���������� �� ������� Extension ���������� �����, ���� �� ������� - �������� ����� ����� � sourcePath 
    jne notFound
    
    mov ax, 0
    ret         
endp

openFile PROC               
	push bx                     
	push dx                                
	push si                                     
                                 
	mov ah, 3Dh			        ; ������� 3Dh - ������� ������������ ����
	mov al, 02h			        ; ����� �������� ����� - ������
	lea dx, sourcePath          ; ��������� � dx �������� ��������� ����� 
	int 21h                     
                              
	jb badOpenSource	        ; ���� ���� �� ��������, �� ������� � badOpenSource
                              
	mov sourceID, ax	        ; ��������� � sourceId �������� �� ax, ���������� ��� �������� �����
                                
	mov ax, 0			        ; ��������� � ax 0, �.�. ������ �� ����� ���������� ��������� �� ��������    
	jmp endOpenProc		        ; ������� � endOpenProc � ��������� ������� �� ���������
                                
badOpenSource:                  
	println badSourceText       ; ������� �������������� ���������
	
	cmp ax, 02h                 ; ���������� ax � 02h
	jne errorFound              ; ���� ax != 02h file error, ������� � errorFound
                                
	println fileNotFoundText    ; ������� ��������� � ���, ��� ���� �� ������  
                                
	jmp errorFound              ; ������� � errorFound
                               
errorFound:                     
	mov ax, 1
	                   
endOpenProc:
    pop si               
	pop dx                                                     
	pop bx                  
	ret                     
ENDP

reverseAllStrings proc             ; ���������, �������� �������� �����
    mov tempDX, 0                  ; �������� tempDX � flagTemp 
    mov flagTemp, 0
    
for1:
    call fseekI                    ; ���������� �� i-������, �.�. ������ ����. ������
    mov bx, sourceID
        
for2:    
    call readSymbolFromFile        ; ��������� ������ � �����
    incrementTempPos 1
    
    cmp ax, 0                      ; ���� ������ �� ������� => ����� �����
    je endFileGG
    cmp [buf], 0                   ; ���� ������� NULL => ����� �����
    je endFileGG
    
    cmp [buf], newLineSymbol       ; ��������� �� cret, �.�. ������� ��� cret, � ������ ����� newl
    je  endString                  ; ���� cret, �� ���� ���������� ������

    jmp for2
    
endString:
    
    mov ax, tempDX                 ; temp ��������� �� ����� ������ => ������� � j
    mov jSymDX, ax
    mov ax, flagTemp
    mov jSymCX, ax
    call decrementEndPos           ; ��������� ����� ����� newl => ��� ���� ��� ��������� ����� ��������� �������� ������
    call decrementEndPos           ; ������ dec - ���������� ����� cret, ������ dec - ���������� ����� ��������� �������� ������
    call reverse                   ; ����������� ������
    
    mov ax, jSymCX                 ; i ��������� �� ������ ����. ������
    mov iSymCX, ax
    mov ax, jSymDX
    mov iSymDX, ax
    call incrementStartPos         ; �.�. i ������ ��������� �� ��������� ������ ������, ���� �������� �� ������ ����., �.�. �� 3 ������� �����
    call incrementStartPos
    call incrementStartPos
    mov ax, iSymDX                 ; temp ��������� �� ������ ����. ������ 
    mov tempDX, ax
    mov ax, iSymCX
    mov flagTemp, ax                 
    
    jmp for1                       ; ���������� ���������
    
endFileGG:
    mov ax, tempDX                 ; ���� ����� ������, �� ���� ���������� � ��������� ������
    mov jSymDX, ax
    mov ax, flagTemp
    mov jSymCX, ax
    call decrementEndPos
    call decrementEndPos
    call reverse 
    
    ret
endp

readSymbolFromFile proc
    push bx
    push dx
    
    mov ah, 3Fh                     ; ��������� � ah ��� 3Fh - ��� �-��� ������ �� �����
	mov bx, sourceID                ; � bx ��������� ID �����, �� �������� ���������� ���������
	mov cx, 1                       ; � cx ��������� ���������� ����������� ��������
	lea dx, buf                     ; � dx ��������� �������� �������, � ������� ����� ��������� ������ �� �����
	int 21h                         ; �������� ���������� ��� ���������� �-���
	
	jnb successfullyRead            ; ���� ������ �� ����� ������� �� ��������� - ������� � goodRead
	
	println errorReadSourceText     ; ����� ������� ��������� �� ������ ������ �� �����
	mov ax, 0                       
	    
successfullyRead:

	pop dx                         
	pop bx
	                                
	ret    	   
endp

reverseFile proc
    push ax
    push bx
    push cx
    push dx
    
    xor cx, cx
    xor dx, dx
    
    mov iSymDX, 0
    mov iSymCX, 0
    
    fseek 0

getLength:                      ; ���������� ����� �����(� ��� ���� ������ ����������� �� �����). 
    call readSymbolFromFile
    cmp ax, 0                   ; ���� ������ �� ������� => ����� �����
    je endGetLength
    cmp [buf], 0                ; ���� ������� NULL => ����� �����
    je endGetLength
    call incrementStartPos
    jmp getLength
    
endGetLength: 
    
    mov ax,iSymDX
    mov jSymDX, ax
    mov ax, iSymCX
    mov jSymCX, ax
     
    mov iSymDX, 0
    mov iSymCX, 0
    
    call decrementEndPos        ; ��������� �� ��������� ������ � �����
    call reverse
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret
endp

reverse proc                    ;reverse symbols between i and j
    push ax
    push iSymCX
    push iSymDX
    push jSymCX
    push jSymDX
    
reverseStart:
     
     mov ax, iSymCX 
     cmp ax, jSymCX            ; ��������� ������� i � j
     jg endReverse
     cmp ax, jSymCX
     je cmpDX
     jmp reverseSym
           
cmpDX:
     mov ax, iSymDX 
     cmp ax, jSymDX
     jg endReverse   
      
reverseSym:   

     call swapSymbols
     call incrementStartPos
     call decrementEndPos
     jmp reverseStart
           
endReverse:

    pop jSymDX
    pop jSymCX
    pop iSymDX
    pop iSymCX    
    pop ax
    ret
endp   

swapSymbols proc
    push ax
    push bx
    push cx
    push dx
    
     call fseekJ
     call readSymbolFromFile
     mov al, buf
     mov jBuf, al
     
     call fseekI
     call readSymbolFromFile
     mov al, buf
     mov iBuf, al
     
     call fseekJ
     mov ah, 40h
     mov bx, sourceID
     mov cx, 1
     lea dx, iBuf
     int 21h
     
     call fseekI
     mov ah, 40h
     mov bx, sourceID
     mov cx, 1
     lea dx, jBuf
     int 21h
     
    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp        

fseekI proc
    push ax
    push bx                     
	push cx                     
	push dx
	
	mov bx, sourceID
    fseek iSymDX
    
    cmp iSymCX, 0
    je endSetPosI
    xor cx, cx    
    mov cx, iSymCX
    
setPosI:
    mov bx, sourceID
    fseekCurrent 32767
    loop setPosI 
    
endSetPosI:

	pop dx                      
	pop cx
	pop bx                      
	pop ax
    ret
endp    
        
fseekJ proc
    push ax
    push bx                     
	push cx                     
	push dx
	
	mov bx, sourceID
    fseek jSymDX
    
    cmp jSymCX, 0
    je endSetPosJ
    xor cx, cx    
    mov cx, jSymCX
    
setPosJ:
    mov bx, sourceID
    fseekCurrent 32767
    loop setPosJ 
    
endSetPosJ:

	pop dx                      
	pop cx
	pop bx                      
	pop ax
    ret
endp 

reverseCRETAndNewLine proc
    push ax
    push bx
    push cx
    push dx
    
    mov bx, sourceID
    fseek 0    
reverseCRET:
    mov bx, sourceID    
    call readSymbolFromFile     ; ��������� ������ � �����
    
    cmp ax, 0                   ; ���� ������ �� ������� => ����� �����
    je endOfFile
    cmp [buf], 0                ; ���� ������� NULL => ����� �����
    je endOfFile
    
    cmp [buf], returnSymbol     ; ��������� �� new line
    je  newlFound

    jmp reverseCRET
    
newlFound:

    
    mov bx, sourceID
    mov ah, 42h                 ; ���������� � ah ��� 42h - �-��� DOS ��������� ��������� �����
	mov al, 1                   ; 1 - ����������� ��������� �� ������� �������
	mov cx, -1                  ; -1 ����� ��������� ����� 
	mov dx, -1	                ; �������� dx, �.� ��������� ��������� �� 0 �������� �� ������ ����� (cx*65536)+dx 
	int 21h
    
     mov ah, 40h
     mov bx, sourceID
     mov cx, 1
     lea dx, newl
     int 21h
     
     mov ah, 40h
     mov bx, sourceID
     mov cx, 1
     lea dx, cret
     int 21h             
     
    jmp reverseCRET                     ; ���������� ���������
    
endOfFile: 
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp    
end main                                                                                                               