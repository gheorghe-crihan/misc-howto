;----------------------------------------------------------------------------;
;                                GusDrive ][                                 ;
;                RAM-Disc Device Driver For Gravis UltraSound                ;
;                      Code by נdATaנ/The CCS-Productions                    ;
;                 (c) 1995-xxxx By נdATaנ/The CCS-Productions                ;
;                             All Rights Reserved                            ;
;                                                                            ;
;   If you find some interesting tips or ideas out of this code, so don't    ;
;  forget to greet me ! If you rip parts out of this code, so you are a big  ;
;                      LAMER !!!  What a shame you are...                    ;
;----------------------------------------------------------------------------;

.386                            ;Support only 386+ (32-bit) ;-)

assume cs:CODE,ds:CODE,es:CODE;ss:_STACK

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;Code segment

CODE segment use16 'CODE'

org 0                           ;SYS start address
;-----------------------------------------------------------------------------
;Driver data

DRVHEADER db 0ffh,0ffh,'CC'     ;Driver ID                      [00/4]
          dw 0000000000000000b  ;Driver attribute               [04/2]
          dw offset STRATEGY    ;Offset strategy routine        [06/2]
          dw offset INTERRUPT   ;Offset interrupt routine       [08/2]
          db 1                  ;Number of devices...           [0A/8]
          db "נdATaנ",1         ;...

;-----------------------------------------------------------------------------
;STRATEGY: DOS strategy routine (called by DOS)
;In : -
;Out: -

PBLOCKPTR dw ?,?                ;Address of DOS parameter block

STRATEGY proc far
           mov PBLOCKPTR,es
           mov PBLOCKPTR+2,bx
           retf
STRATEGY endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;INTERRUPT: DOS interrupt routine (called by DOS)
;In : -
;Out: -

FUNCTION equ 2
STATUS   equ 3

JUMPTABLE dw offset FUNCTION00  ;JUMP-table/Function 00 - Init
          dw offset FUNCTION01  ;Function 01 - Media check
          dw offset FUNCTION02  ;Function 02 - Create BPB
          dw offset FUNCTIONxx  ;Function 03 - Direct read
          dw offset FUNCTION04  ;Function 04 - Read
          dw offset FUNCTIONxx  ;Function 05 - Char read w/o remove
          dw offset FUNCTIONxx  ;Function 06 - Check input status
          dw offset FUNCTIONxx  ;Function 07 - Clear input buffer
          dw offset FUNCTION08  ;Function 08 - Write
          dw offset FUNCTION08  ;Function 09 - Write and verify
          dw offset FUNCTIONxx  ;Function 0A - Check output status
          dw offset FUNCTIONxx  ;Function 0B - Clear output buffer
          dw offset FUNCTIONxx  ;Function 0C - Direct write

INTERRUPT proc far
            pusha
            push ds
            push es
            pushf

            mov es,PBLOCKPTR
            mov si,PBLOCKPTR+2
            mov bl,es:[si+FUNCTION]   ;Get function number
            cmp bl,12
            ja short UNKNOWNCMD
            xor bh,bh
            shl bx,1
            call [offset JUMPTABLE+bx]

            mov ax,100h         ;No errors+Set READY-Bit
            jmp short DONE

UNKNOWNCMD: mov ax,8003h        ;Error+Unknown command

      DONE: mov es:[si+STATUS],ax   ;Store status in PB

            popf
            pop es
            pop ds
            popa
            retf
INTERRUPT endp

;-----------------------------------------------------------------------------
;FUNCTION01: Media check (called by INTERRUPT)
;In : -
;Out: -

MEDIASTAT equ 0eh

FUNCTION01 proc near
             mov byte ptr es:[si+MEDIASTAT],0
             ret
FUNCTION01 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;FUNCTION02: Create BPB (called by INTERRUPT)
;In : -
;Out: -

BYPS   equ 512                  ;Bytes/sector
SLSV   equ 9                    ;Sector-to-linear shift value
BPBADR equ 12h

BOOTSECT db 'CCS'               ;JMP-Command                      [00/3]
         db 'GusDrv]['          ;Info                             [03/8]
BPB      dw BYPS                ;Bytes/sector                     [0B/2]
         db 1                   ;Sectors/cluster                  [0D/1]
         dw 1                   ;# of reserved sectors            [0E/2]
         db 1                   ;# of FAT's                       [10/1]
         dw 171                 ;# of entries in main directory   [11/2]
MAXSECT  dw ?                   ;# of total sectors available     [13/2]
         db 0f8h                ;Media descriptor                 [15/1]
         dw 6                   ;Sectors/FAT                      [16/2]
OTHERNFO dw 0                   ;Tracks/Sect                      [18/2]
         dw 0                   ;# of heads                       [1A/2]
         dw 0                   ;Distance 1.Vol-Sect<>1.Sect med. [1C/2]
BOOTSECTEND equ this byte

FUNCTION02 proc near
             mov es:[si+BPBADR+2],cs
             mov word ptr es:[si+BPBADR],offset BPB
             ret
FUNCTION02 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;FUNCTION04: Read (called by INTERRUPT)
;In : -
;Out: -

BUFPTR     equ 0eh
NUMSECTS   equ 12h
FIRSTSECT  equ 14h

BPBVECT dw offset BPB,?

FUNCTION04 proc near
             push es

             mov dx,GUSbase
             mov bx,es:[si+NUMSECTS]
             mov ecx,es:[si+FIRSTSECT]
             mov di,es:[si+BUFPTR]
             mov es,es:[si+BUFPTR+2]
             call GUSREAD

             pop es
             ret
FUNCTION04 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;FUNCTION08: Write (called by INTERRUPT)
;In : -
;Out: -

FUNCTION08 proc near
             push ds
             push si

             mov dx,GUSbase
             mov bx,es:[si+NUMSECTS]
             mov ecx,es:[si+FIRSTSECT]
             mov ds,es:[si+BUFPTR+2]
             mov si,es:[si+BUFPTR]
             call GUSWRITE

             pop si
             pop ds
             ret
FUNCTION08 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;FUNCTIONx: Used as dummy for the functions 03,06,07,0A,0B and 0C
;           (called by INTERRUPT)
;In : -
;Out: -

FUNCTIONxx proc near
             ret
FUNCTIONxx endp

;-----------------------------------------------------------------------------
;*GUS ROUTINEZ*

;GF1WRITE8: Writes data in GF1's selected register (8-bit)
;In : AL - Register number
;     CL - Data
;     DX - GUS base address
;Out: -

GF1WRITE8 proc near
            push dx
            add dx,103h
            out dx,al
            inc dx
            inc dx
            mov al,cl
            out dx,al
            pop dx
            ret
GF1WRITE8 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GF1WRITE16: Writes data in GF1's selected register (16-bit)
;In : AL - Register number
;     CX - Data
;     DX - GUS base address
;Out: -

GF1WRITE16 proc near
             push dx
             add dx,103h
             out dx,al
             inc dx
             mov ax,cx
             out dx,ax
             pop dx
             ret
GF1WRITE16 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;ADRSELMRDS: Selects the GUS' DRAM address in ECX using the MRDS technique
;In : ECX - DRAM address
;Out: -

ADRSELMRDS proc near
             push ecx

             mov ebp,cs:GUSmemsz ;MRDS ;)
             sub ebp,ecx
             mov ecx,ebp

             mov al,43h          ;DRAM I/O address (43h,low)
             call GF1WRITE16     ;Write CX
             mov al,44h          ;DRAM I/O address (44h,hi)
             shr ecx,16          ;Get low byte of CXH in CL
             call GF1WRITE8      ;Write CL

             pop ecx
             ret
ADRSELMRDS endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSPEEK: Peeks a byte at location ECX in AL (uses ADRSELMRDS)
;In : ECX - DRAM location
;     DX  - GUS base address
;Out: AL  - Data byte

GUSPEEK proc near
          call ADRSELMRDS

          push dx
          add dx,107h           ;DRAM I/O
          in al,dx
          pop dx
          ret
GUSPEEK endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSPOKE: Pokes the byte in AL at location ECX (uses ADRSELMRDS)
;In : ECX - DRAM location
;     AL  - Data byte
;     DX  - GUS base address
;Out: -

GUSPOKE proc near
          push ax
          call ADRSELMRDS
          pop ax

          push dx
          add dx,107h           ;DRAM I/O
          out dx,al
          pop dx
          ret
GUSPOKE endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSREAD: Reads data from GUS' DRAM into the buffer at ES:DI
;In : BX  - Number of sectors to read
;     ECX - Number of the start sector
;     ES  - Segment of the destination buffer
;     DI  - Offset of the destination buffer
;     DX  - GUS base address
;Out: -

GUSREAD proc near
          shl ecx,SLSV          ;Calculate DRAM position
   NSECT: push bx
          mov bx,BYPS           ;Bytes/sector
    CONT: call GUSPEEK          ;Get DRAM byte at ECX in AL...
          stosb                 ;...and store it at ES:DI
          inc ecx
          dec bx                ;Next byte in the sector
          jne short CONT        ;Last byte ?
          pop bx                ;All bytes in this sector read
          dec bx                ;Next sector
          jne short NSECT       ;Last sector ?
          ret
GUSREAD endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSWRITE: Writes data into the GUS' DRAM from the buffer at DS:SI
;In : BX  - Number of sectors to read
;     ECX - Number of the start sector
;     DS  - Segment of the destination buffer
;     SI  - Offset of the destination buffer
;     DX  - GUS base address
;Out: -

GUSWRITE proc near
           shl ecx,SLSV         ;Calculate DRAM position
   NSECT2: push bx
           mov bx,BYPS          ;Bytes/sector
    CONT2: lodsb                ;Get data from buffer at DS:SI in AL..
           call GUSPOKE         ;...and store it in GUS' DRAM at ECX
           inc ecx
           dec bx               ;Next byte in the sector
           jne short CONT2      ;Last byte ?
           pop bx               ;All bytes in this sector written
           dec bx               ;Next sector
           jne short NSECT2     ;Last sector ?
           ret
GUSWRITE endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;CHKGDRV: GusDrive installation info area (uses vector 0000:0060/INT18H)
;In : -
;Out: -

CHKGDRV proc near
          db 0eah               ;JMP FAR instruction        ( 1 byte)
JMPINT18  dw 0,0                ;Points to INT18h-handler   ( 4 bytes)
          db 'GusDrive'         ;ID-string                  ( 8 bytes)
          db 2,00h              ;Version number 2.00        ( 2 bytes)
DRVLETT   db 0                  ;GusDrive drive letter      ( 1 byte)
          db 'נdATaנ/TCCSP'     ;Producer                   (12 bytes)
GUSbase   dw 210h               ;GUS base address           ( 2 bytes)
GUSmemsz  dd 0                  ;GUS mem-size               ( 4 bytes)
CHKGDRV endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GF1DELAY: Delay routine for GF1 using a dummy DRAM read access to perform
;          a system independant delay time.
;In : -
;Out: -

GF1DELAY proc near
           mov cx,30
      DLY: call GUSPEEK
           loop DLY
           ret
GF1DELAY endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSINIT: Resets and intializes the GUS
;In : DX - GUS base address
;Out: -

GUSINIT proc near
          cli
          push ecx

          mov al,4ch            ;Reset regz
          xor cl,cl             ;Reset GF1
          call GF1WRITE8
          call GF1DELAY
          mov al,4ch            ;Enable GF1
          mov cl,7
          call GF1WRITE8
          call GF1DELAY

          add dx,0fh            ;2xFh - Register Control (only 3.4 or above)
          mov al,5              ;Clear IRQ's At Power Up
          out dx,al
          sub dx,0fh
          mov al,0bh            ;Enable latches
          out dx,al
          add dx,0bh            ;2xBh - Register Data
          xor al,al             ;Clear IRQ's
          out dx,al
          add dx,4
          mov al,6              ;Jumper Regz
          out dx,al
          sub dx,4
          mov al,GUSCFG         ;Get Joystick/Midi setup
          shr al,4              ;Get high-nibble to low
          out dx,al
          add dx,4
          mov al,0              ;IRQ/DMA Config Regz
          out dx,al
          sub dx,0fh
          mov al,GUSCFG         ;Get IN/OUT setup
          and al,0fh            ;Kill high-nibble
          or al,01000000b       ;Control Regz Select (IRQ)
          out dx,al             ;Mix Control Regz
          add dx,0bh
          mov al,IRQSET
          out dx,al
          sub dx,0bh
          mov al,GUSCFG         ;Get IN/OUT setup again
          and al,0fh            ;Kill high-nibble/Control Regz Sel. (DMA)
          out dx,al             ;Mix Control Regz
          add dx,0bh
          mov al,DMASET
          out dx,al
          sub dx,0bh

          mov al,41h            ;DRAM DMA Control
          mov cl,00100000b      ;DMA IRQ enable
          call GF1WRITE8

          mov al,45h            ;Time Control
          mov cl,00001100b      ;Enable timer 1 & timer 2 IRQ
          call GF1WRITE8

          mov al,49h            ;Sampling Control Regz
          mov cl,00100000b      ;DMA IRQ enable
          call GF1WRITE8

          pop ecx
          sti
          ret
GUSINIT endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;ADRSELECT: Selects the GUS' DRAM address in ECX (only for auto-detection)
;In : ECX - DRAM address
;Out: -

ADRSELECT proc near
            push ecx

            mov al,43h          ;DRAM I/O address (43h,low)
            call GF1WRITE16     ;Write CX
            mov al,44h          ;DRAM I/O address (44h,hi)
            shr ecx,16          ;Get low byte of CXH in CL
            call GF1WRITE8      ;Write CL

            pop ecx
            ret
ADRSELECT endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;_GUSPEEK: Peeks a byte at location ECX in AL (uses ADRSELECT)
;In : ECX - DRAM location
;     DX  - GUS base address
;Out: AL  - Data byte

_GUSPEEK proc near
           call ADRSELECT

           push dx
           add dx,107h           ;DRAM I/O
           in al,dx
           pop dx
           ret
_GUSPEEK endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;_GUSPOKE: Pokes the byte in AL at location ECX (uses ADRSELECT)
;In : ECX - DRAM location
;     AL  - Data byte
;     DX  - GUS base address
;Out: -

_GUSPOKE proc near
           push ax
           call ADRSELECT
           pop ax

           push dx
           add dx,107h           ;DRAM I/O
           out dx,al
           pop dx
           ret
_GUSPOKE endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSDETECT: AutoDetects the GUS and its mem-size
;In : -
;Out: cf=0 - Found, cf=1 - Not found

GUSDETECT proc near
            mov dx,GUSbase      ;Get GUS base address to scan
            xor ecx,ecx         ;Set DRAM location to 0
   TRYNEXT: call GUSINIT        ;Try to initialize the GUS

            call _GUSPEEK
            xchg al,bl
            mov al,'C'          ;Write a 'C'
            call _GUSPOKE

            call _GUSPEEK       ;Get data at 0 in AL
            cmp al,'C'          ;Is it a 'C' ?
            je short GFOUND     ;Yep, GUS found :)

            add dx,10h          ;Next address
            cmp dx,260h         ;Base address equal to 260h ?
            jne short TRYNEXT   ;No, try next
            jmp GNOTFOUND       ;Yes, no GUS found :(

    GFOUND: mov GUSbase,dx
            xchg al,bl
            call _GUSPOKE
            push dx
            shr dl,4
            or dl,30h
            mov GUSMSGb,dl
            mov dx,offset GUSMSGa
            call PRINT
            pop dx

            call _GUSPEEK       ;Look for "no valid memory"
            mov bl,al           ;Save old byte
            shl bx,8
            mov al,11
            call _GUSPOKE
            inc ecx
            call _GUSPEEK
            mov bl,al           ;Save old byte
            mov al,71
            call _GUSPOKE
            dec ecx
            call _GUSPEEK
            cmp al,11
            jne SIZEe
            inc ecx
            call _GUSPEEK
            cmp al,71
            jne short SIZEe
            mov al,bl           ;Get old byte
            call _GUSPOKE
            dec ecx
            shr bx,8
            mov al,bl           ;Get old byte
            call _GUSPOKE

  NEXTBANK: add ecx,256*1024    ;Detect mem-size
            mov GUSmemsz,ecx

            call _GUSPEEK       ;Get old data...
            push ax             ;...and store it

            mov al,0cch         ;Write 0CCh
            call _GUSPOKE

            call _GUSPEEK       ;Get data at current bank in AL...
            mov bl,al           ;...and save it in BL

            pop ax              ;And then store the old byte
            call _GUSPOKE

            cmp bl,0cch         ;Is it 0CCh ?
            jne short BANKEND   ;No more banks available

            cmp ecx,1024*1024
            je short BANKEND
            jmp short NEXTBANK

   BANKEND: dec GUSmemsz
            mov dx,offset GUSMSGc
            call PRINT

            cmp ecx,256*1024
            jne short SIZEb
            mov dx,offset DRAMa
            jmp short DISPMEMS
     SIZEb: cmp ecx,512*1024
            jne short SIZEc
            mov dx,offset DRAMb
            jmp short DISPMEMS
     SIZEc: cmp ecx,768*1024
            jne short SIZEd
            mov dx,offset DRAMc
            jmp short DISPMEMS
     SIZEd: mov dx,offset DRAMd
            jmp short DISPMEMS
     SIZEe: mov dx,offset GUSMSGd
            call PRINT
            jmp short NOINST

  DISPMEMS: call PRINT

            shr ecx,SLSV
            mov MAXSECT,cx

            clc
            jmp short GDRDY

 GNOTFOUND: mov dx,offset GUSNOTF
            call PRINT
    NOINST: stc

     GDRDY: ret
GUSDETECT endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GUSREV: Displays the GUS revision
;In : -
;Out: -

GUSREV proc near
         mov dx,offset TYPETXT
         call PRINT

         mov dx,GUSbase
         add dx,506h            ;Revision level (7x6h)
         in al,dx

         cmp al,5
         je short RTXTa         ;GUS 3.7 with L/R-flip problem ?

         cmp al,6               ;GUS 3.7 ?
         je short RTXTb
         cmp al,7
         je short RTXTb
         cmp al,8
         je short RTXTb
         cmp al,9
         je short RTXTb

         cmp al,0ah             ;GUS-MAX 1.8 ?
         je short RTXTc

         cmp al,0bh             ;GUS-MAX 2.1 ?
         je short RTXTd

         cmp al,0ffh            ;Previous GUS release or no GUS ?
         je short RTXTe

         mov dx,offset REVTXTf  ;Unknown GUS release or no GUS
         call PRINT
         ret

  RTXTa: mov dx,offset REVTXTa  ;GUS 3.7 with L/R-flip problem
         call PRINT
         ret

  RTXTb: mov dx,offset REVTXTb  ;GUS 3.7
         call PRINT
         ret

  RTXTc: mov dx,offset REVTXTc  ;GUS-MAX 1.8
         call PRINT
         call SETCS4231
         ret

  RTXTd: mov dx,offset REVTXTd  ;GUS-MAX 2.1
         call PRINT
         call SETCS4231
         ret

  RTXTe: mov dx,offset REVTXTe  ;Previous GUS release or no GUS
         call PRINT
         ret
GUSREV endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;SETCS4231: Setups the CODEC chip (only GUS with CODEC-chip CS 4231 !)
;In : -
;Out: -

SETCS4231 proc near
            ;!!! ATTENTION !!!
            ;The following CODEC-routine has been developed experimentally,
            ;since I don't have any data sheet from the CS4231-chip.
            ;This routine should enable any signal-input and set the output
            ;volume level to 3 for both channels,left and right. I found out
            ;the registers with a small Pascal-routine I have coded, wich sent
            ;different data to the two ports of the CODEC-chip using two
            ;counters ;).
            ;It works only on GUS-MAX and the daughter cards using this chip
            ;at the same location.

            mov dx,GUSbase
            add dx,106h          ;UltraMax Control Regz
            mov al,dl            ;Get X-value of 2X0h
            shr al,4
            or al,40h            ;Enable CODEC
            out dx,al
            add dx,6             ;Regs select

            mov al,12            ;Signal input source
            out dx,al
            inc dx               ;Data port
            mov al,0             ;Signal channel select ? (GF1 in)
            out dx,al
            dec dx
            mov al,18            ;Select right channel
            out dx,al
            inc dx
            mov al,3             ;Set volume to 3
            out dx,al
            dec dx
            mov al,19            ;Select left channel
            out dx,al
            inc dx
            mov al,3             ;Set volume to 3
            out dx,al
            dec dx

            mov al,12            ;Signal input source
            out dx,al
            inc dx               ;Data port
            mov al,64            ;Signal channel select ? (Line-In/Mic-In)
            out dx,al
            dec dx
            mov al,18            ;Select right channel
            out dx,al
            inc dx
            mov al,3             ;Set volume to 3
            out dx,al
            dec dx
            mov al,19            ;Select left channel
            out dx,al
            inc dx
            mov al,3             ;Set volume to 3
            out dx,al
            ret
SETCS4231 endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;FORMAT: Formats the GUS memory
;In : -
;Out: -

FORMAT proc near
         mov dx,GUSbase
         mov ecx,30*512         ;Fill first 30 sectors with zeroes
         xor al,al
CLRGMEM: call GUSPOKE
         loop CLRGMEM

         push si                
         xor ecx,ecx
         mov si,offset BOOTSECT
  WBOOT: lodsb                  ;Write boot-sector and BPB
         call GUSPOKE
         inc ecx
         cmp si,offset BOOTSECTEND
         jne short WBOOT

         mov ecx,7*512
         mov si,offset VOLUMEL
   WVOL: lodsb                  ;Write volume label
         call GUSPOKE
         inc ecx
         cmp si,offset ENDVOLUMEL
         jne short WVOL
         pop si

         mov ecx,512            ;Now write media descriptor and FAT-id
         mov al,0f8h
         call GUSPOKE
         mov al,0ffh
         inc ecx
         call GUSPOKE
         inc ecx
         call GUSPOKE
         ret
FORMAT endp

;-----------------------------------------------------------------------------
;FUNCTION 00: Init driver (called by INTERRUPT)
;In : -
;Out: -

DEVICENAME equ 16h

NUMDEVICES equ 0dh
NEXTFREE   equ 0eh
BPBVECTADR equ 12h
ERRORFLAG  equ 17h

FUNCTION00 proc near
             push es
             push si
             mov ax,3           ;Init screen
             int 10h

             cld
             push cs
             pop ds

             call DECODEMSG

             mov si,offset MAINSCR
             push 0b800h
             pop es
             xor di,di
             mov cx,offset (ENDMAINSCR-MAINSCR)/2
       DISP: lodsw
             stosw
             loop DISP

             mov ah,2           ;Set cursor
             xor bh,bh
             mov dx,500h
             int 10h

             push 0
             pop es
             mov bx,60h
             mov ax,es:[bx]
             mov dx,es:[bx+2]
             mov word ptr es:[bx],offset CHKGDRV
             mov es:[bx+2],cs
             mov JMPINT18,ax
             mov JMPINT18+2,dx
             pop si
             pop es

             mov al,es:[si+DEVICENAME]   ;Get drive letter from DOS
             add al,"A"
             mov DRVINSb,al
             mov FMTMSGb,al
             mov DRVLETT,al

             call GUSDETECT     ;AutoDetect GUS and its mem-size
             jnc short FOUND

   NOTFOUND: mov ax,800ch       ;Error+Common error
             ret

      FOUND: call GUSREV        ;Print GUS revision

             mov dx,GUSbase
             mov ecx,0e16h      ;Check drive for destruction...
             call GUSPEEK
             cmp al,byte ptr D&T
             jne short FMT
             inc ecx
             call GUSPEEK
             cmp al,byte ptr D&T+1
             jne short FMT
             inc ecx
             call GUSPEEK
             cmp al,byte ptr D&T+2
             jne short FMT
             inc ecx
             call GUSPEEK
             cmp al,byte ptr D&T+3
             jne short FMT
             jmp short NOFMT

        FMT: mov dx,offset FMTMSGa   ;...and format it, if contents destroyed
             call PRINT
             call FORMAT
             mov dx,offset FMTMSGe
             call PRINT

      NOFMT: call PRINTSET

             mov dx,offset DRVINSa
             call PRINT

             mov byte ptr es:[si+NUMDEVICES],1
             mov es:[si+NEXTFREE+2],cs
             mov word ptr es:[si+NEXTFREE],offset GF1DELAY
             mov es:[si+BPBVECTADR+2],cs
             mov word ptr es:[si+BPBVECTADR],offset BPBVECT
             mov byte ptr es:[si+ERRORFLAG],0
             ret
FUNCTION00 endp

;-----------------------------------------------------------------------------
;EXEMAIN: EXE-routine

EXEMAIN proc near
          push cs
          pop ds
          cld

          call DECODEMSG

          mov dl,GUSCFG         ;Get settings in DL

          mov cl,es:[80h]       ;Get number of chars
          or cl,cl              ;Zero ?
          je GETENV
          xor bx,bx

NEXTCHAR: mov al,es:[81h+bx]
          cmp al,'-'            ;Parameter sync
          je short PSYNCFND
          inc bx
          loop NEXTCHAR
          jmp short GETENV      ;End of parameters

PSYNCFND: inc bx                ;Get char after
          mov al,es:[81h+bx]
          cmp al,'a'
          jae short LOWEROK
          add al,32             ;Convert to lower case

 LOWEROK: cmp al,'?'+32         ;Show help ?
          jne short P1
          mov dx,offset EXEMSG
          call PRINT
          mov dx,offset HELP
          call PRINT
          jmp ENDEXE

      P1: cmp al,'r'            ;Show full version number ?
          jne short P2
          mov dx,offset EXEMSG
          call PRINT
          mov dx,offset FULLREV
          call PRINT
          jmp ENDEXE

      P2: cmp al,'s'            ;Quiet mode ?
          jne short P3
          mov byte ptr PRINT,0c3h   ;RET ;-)

      P3: cmp al,'f'            ;Format drive ?
          jne short P4
          mov FMTFLAG,1         ;Set flag

      P4: cmp al,'i'            ;Init GUS' DRAM ?
          jne short P5
          mov DINIT,1

      P5: cmp al,'m'            ;Enable mic-in ?
          jne short P6
          or dl,00001100b

      P6: cmp al,'o'            ;Enable line-out ?
          jne short P7
          and dl,11111101b

      P7: cmp al,'l'            ;Enable line-in ?
          jne short P8
          and dl,11111110b

      P8: cmp al,'e'            ;Enable joystick port decode ?
          jne short P9
          or dl,01000000b

      P9: cmp al,'d'            ;Disable joystick port decode ?
          jne short P10
          and dl,10111111b

     P10: mov GUScfg,dl
          jmp NEXTCHAR

  GETENV: mov dx,offset EXEMSG  ;Print title message
          call PRINT

          push es               ;Check wether GusDrive is installed or not
          push 0
          pop es
          mov bx,60h
          mov di,es:[bx]
          add di,5
          mov es,es:[bx+2]
          mov si,offset GDRVID
          mov cx,8
          rep cmpsb
          je short GDDET

          mov dx,offset GDNDET
          call PRINT
          pop es
          jmp short GDNODET

   GDDET: mov al,es:[di]
          add al,30h
          mov GDDETb,al
          inc di
          mov al,es:[di]
          shr al,4
          add al,30h
          mov GDDETc,al
          mov al,es:[di]
          and al,0fh
          add al,30h
          mov GDDETd,al
          inc di
          mov al,es:[di]
          mov GDDETe,al
          pop es
          mov dx,offset GDDETa
          call PRINT

 GDNODET: mov es,es:[2ch]       ;Look for ULTRASND environment variable
          xor bx,bx
    NPOS: mov di,bx
          mov si,offset UENVSN
          mov cx,8
          rep cmpsb
          je short STRFND
          inc bx
          mov ax,es:[bx]
          or ax,ax
          jne short NPOS

          mov dx,offset UENVSTa ;ULTRASND environment variable not found
          call PRINT
          jmp NOPARAM           

  STRFND: add bx,8              ;Skip the ULTRASND-string
  CPYNX1: mov al,es:[bx]        ;Get next char
          cmp al,255            ;Skip any kind of spaces, ASCII-255
          je short SKIPSPC1
          cmp al,' '            ;Space
          je short SKIPSPC1
          cmp al,9              ;Tab
          je short SKIPSPC1
          cmp al,'='            ;Is it a '=' ?
          je short ENVRDY       ;Yope, the right ULTRASND-var found
          jmp short NPOS
SKIPSPC1: inc bx
          jmp short CPYNX1

  ENVRDY: sub di,8              ;Set pointer at beginning of the ULTRASND-str.
          mov bx,di
          mov di,offset UENVSTb ;Now copy the complete var in own buffer
  CPYNX2: mov al,es:[bx]
          or al,al
          je short ENDENVST
          cmp al,255            ;Skip any kind of spaces, ASCII-255
          je short SKIPSPC2
          cmp al,' '            ;Space
          je short SKIPSPC2
          cmp al,9              ;Tab
          je short SKIPSPC2
          mov ds:[di],al
          inc di
SKIPSPC2: inc bx
          jmp short CPYNX2

ENDENVST: mov ax,0a0dh          ;Make the environment variable printable...
          mov ds:[di],ax
          inc di
          inc di
          mov al,'$'
          mov ds:[di],al

          mov dx,offset UENVSTa
          call PRINT

          ;The following routine sets the GUS' IRQ- and DMA-channels to the
          ;values found in the ULTRASND environment variable. Note, that this
          ;routine can handle this string properly only if the format
          ;"ULTRASND=aaa,(b)b,(c)c,(d)d,(e)eCRLF" is guaranteed. Otherwise
          ;unexpected keep backs will result.

          mov si,offset UENVSTb
FNDEQUCH: lodsb                 ;Find '='
          cmp al,13
          je short ENDSTR
          cmp al,'='
          jne short FNDEQUCH    ;Skip "ULTRASND="

          xor cx,cx             ;Parameter counter
FINDCOMM: lodsb
          cmp al,13
          je short ENDSTR
          cmp al,','
          jne short FINDCOMM    ;Skip base address

   NEXTP: xor bx,bx             ;Contains the ASCII-chars
FINDNEXT: lodsb                 ;Get first ASCII-char
          cmp al,13
          je short ENDSTR
          cmp al,','            ;End of number ?
          je short FINDNEXT
          mov bh,al             ;Nope, then transfer ist to BH
          lodsb
          cmp al,13
          je short ENDSTR
          cmp al,','            ;End of number ?
          je short STORE
          xchg bl,bh            ;Nope, then it is the hi ASCII-char
          or bh,al              ;Put low ASCII-char in BL
   STORE: push bx               ;Now store the two-digit ASCII-string
          inc cx
          cmp cx,4              ;Read max. 4 parameters
          jne short NEXTP

  ENDSTR: cmp cx,4              ;Stack correction
          je short STACKOK
          push bx
          inc cx
          jmp short ENDSTR

 STACKOK: pop bx
          mov word ptr PAR2TXb,bx   ;IRQ Channel 2
          mov dx,offset PAR2TXa
          call PRINT
          call ASCII2BCD
          call GETIRQVAL
          movzx bp,al
          shl bp,3

          pop bx                ;IRQ channel 1
          mov word ptr PAR1TXb,bx
          mov dx,offset PAR1TXa
          call PRINT
          call ASCII2BCD
          call GETIRQVAL
          or bp,ax
          xchg ax,bp
          mov IRQSET,al

          pop bx                ;DMA channel 2
          mov word ptr PAR4TXb,bx
          mov dx,offset PAR4TXa
          call PRINT
          call ASCII2BCD
          call GETDMAVAL
          movzx bp,al
          shl bp,3

          pop bx                ;DMA channel 1
          mov word ptr PAR3TXb,bx
          mov dx,offset PAR3TXa
          call PRINT
          call ASCII2BCD
          call GETDMAVAL
          or bp,ax
          xchg ax,bp
          mov DMASET,al

 NOPARAM: call GUSDETECT
          jc short ENDEXE

          call GUSREV
          call PRINTSET         ;Now print the settings

          mov al,DINIT          ;Init ?
          or al,al
          je short NOINIT
          call INITDRAM

  NOINIT: mov al,FMTFLAG        ;Format ?
          or al,al
          je short ENDEXE
          push 0
          pop es
          mov bx,60h
          mov dx,es:[bx+2]
          mov bx,es:[bx]
          mov es,dx
          mov al,es:[bx+15]
          mov FMTMSGd,al
          mov dx,offset FMTMSGc
          call PRINT
          call FORMAT
          mov dx,offset FMTMSGe
          call PRINT

  ENDEXE: mov ax,4cCCh          ; ;)
          int 21h
EXEMAIN endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;INITDRAM: Fills the complete memory of the GUS with zeroes
;In : -
;Out: -

INITDRAM proc near
           mov dx,offset INITa
           call PRINT

           mov ecx,GUSMEMsz
 POKENEXT: mov dx,GUSbase
           xor al,al
           call _GUSPOKE
           cmp cx,8000h
           jne short PLOOP
           mov dx,offset INITC
           call PRINT
    PLOOP: loopd POKENEXT

           mov dx,offset INITb
           call PRINT
           ret
INITDRAM endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;PRINT: Prints a text at current cursor position
;In : DX - Offset text
;Out: -

PRINT proc near
        mov ah,9
        int 21h
        ret
PRINT endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;PRINTSET: Prints the settings of the GUS on the screen
;In : -
;Out: -

PRINTSET proc near
           mov cl,GUSCFG
           not cl
           mov dx,offset CFGTXTa
           call PRINT
           test cl,00000001b
           call PRNTXT
           mov dx,offset CFGTXTb
           call PRINT
           test cl,00000010b
           call PRNTXT
           mov dx,offset CFGTXTc
           call PRINT
           not cl
           test cl,00000100b
           call PRNTXT
           shr cl,4
           mov dx,offset CFGTXTd
           call PRINT
           test cl,00000100b
           call PRNTXT
           ret

   PRNTXT: je short DIS
           mov dx,offset ENABLT
           jmp short PRN
      DIS: mov dx,offset DISABLT
      PRN: call PRINT
    ENDPS: ret
PRINTSET endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;ASCII2BCD: Converts the ASCII-number in BX to a BCD value in CL
;In : BX - ASCII-Number (reversed order !)
;Out: CL - BCD value

ASCII2BCD proc near
            mov cl,bl
            sub cl,'0'
            shl cl,4
            sub bh,'0'
            or cl,bh
            ret
ASCII2BCD endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GETDMAVAL: Converts the BCD DMA-value in BX to the GUS-specific value in AL
;In : CL - BCD value of the DMA
;Out: AL - GUS-specific DMA value

GETDMAVAL proc near
            mov al,1
            push si
            mov si,offset DMALST
    SRCDMA: push ax
            lodsb
            mov ch,al
            pop ax
            cmp ch,cl
            je short DMAOK
            inc al
            cmp al,8
            jne short SRCDMA
            xor al,al           ;Set no DMA
     DMAOK: pop si
            ret
GETDMAVAL endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;GETIRQVAL: Converts the BCD IRQ-value in BX to the GUS-specific value in CL
;In : CL - BCD value of the IRQ
;Out: AL - GUS-specific IRQ value

GETIRQVAL proc near
            mov al,1
            push si
            mov si,offset IRQLST
    SRCIRQ: push ax
            lodsb
            mov ch,al
            pop ax
            cmp ch,cl
            je short IRQOK
            inc al
            cmp al,8
            jne short SRCIRQ
            mov al,7            ;Set IRQ to 7
     IRQOK: pop si
            ret
GETIRQVAL endp

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;DECODEMSG: Decodes the program data
;In : -
;Out: -

DECODEMSG proc near
            push es
            push cs
            pop es
            mov cx,offset (ENDDATA-STARTDATA+7)
            mov si,offset STARTDATA
            mov di,si
   CONTDEC: lodsb
            ror al,cl
            xor al,77
            stosb
            loop CONTDEC
            pop es
            ret
DECODEMSG endp

;-----------------------------------------------------------------------------
;Messages

STARTDATA db 'startdata'

MAINSCR db 032,063,218,063,196,063,196,063,196,063,196,063,196,063,196
        db 063,196,063,196,063,196,063,196,063,196,063,196,063,196,063
        db 196,063,196,063,196,063,196,063,196,063,196,063,196,063,196
        db 063,196,063,196,063,196,063,196,063,196,063,196,063,196,063
        db 196,063,196,063,196,063,196,063,196,063,196,063,196,063,196
        db 063,196,063,196,063,196,063,196,063,196,063,196,063,196,063
        db 196,063,196,063,196,063,196,063,196,063,196,063,196,063,196
        db 063,196,063,196,063,196,063,196,063,196,063,196,063,196,063
        db 196,063,196,063,196,063,196,063,196,063,196,063,196,063,196
        db 063,196,063,196,063,196,063,196,063,196,063,196,063,196,063
        db 196,063,196,063,196,063,191,048,032,063,032,063,179,063,032
        db 063,032,063,032,063,032,063,032,063,032,063,032,063,032,063
        db 032,063,032,063,032,063,032,063,032,063,032,063,032,063,032
        db 063,032,063,032,063,032,063,032,063,032,063,032,063,032,063
        db 032,063,032,063,032,063,032,063,032,063,071,062,250,049,117
        db 062,250,049,115,062,250,049,068,062,250,049,114,062,250,049
        db 105,062,250,049,118,062,250,049,101,062,250,049,250,049,250
        db 049,093,062,091,062,032,063,032,063,032,063,032,063,032,063
        db 032,063,032,063,032,063,032,063,032,063,032,063,032,063,032
        db 063,032,063,032,063,032,063,032,063,032,063,032,063,032,063
        db 032,063,032,063,032,063,032,063,032,063,032,063,032,063,032
        db 063,179,048,032,063,032,063,179,063,032,063,032,063,032,063
        db 032,063,032,063,032,063,032,063,032,063,032,063,032,063,032
        db 063,032,063,032,063,032,063,067,059,111,059,112,059,121,059
        db 114,059,105,059,103,059,104,059,116,059,032,059,049,059,057
        db 059,057,059,053,059,045,059,120,059,120,059,120,059,120,059
        db 032,059,098,059,121,059,032,059,240,059,100,059,065,059,084
        db 059,097,059,240,059,047,059,084,059,104,059,101,059,032,059
        db 067,059,067,059,083,059,045,059,080,059,114,059,111,059,100
        db 059,117,059,099,059,116,059,105,059,111,059,110,059,115,059
        db 032,063,032,063,032,063,032,063,032,063,032,063,032,063,032
        db 063,032,063,032,063,032,063,032,063,032,063,179,048,032,063
        db 032,063,192,063,196,048,196,048,196,048,196,048,196,048,196
        db 048,196,048,196,048,196,048,196,048,196,048,196,048,196,048
        db 196,048,196,048,196,048,196,048,196,048,196,048,196,048,196
        db 048,196,048,196,048,196,048,196,048,196,048,196,048,196,048
        db 196,048,196,048,196,048,196,048,196,048,196,048,196,048,196
        db 048,196,048,196,048,196,048,196,048,196,048,196,048,196,048
        db 196,048,196,048,196,048,196,048,196,048,196,048,196,048,196
        db 048,196,048,196,048,196,048,196,048,196,048,196,048,196,048
        db 196,048,196,048,196,048,196,048,196,048,196,048,196,048,196
        db 048,196,048,196,048,196,048,196,048,196,048,196,048,196,048
        db 196,048,196,048,196,048,217,048,032,063
ENDMAINSCR equ this byte

FULLREV db '‏ GusDrive Version: 2.00',13,10,'$'

GUSMSGa db '‏ Gravis UltraSound AutoDetected At 2'
GUSMSGb db '?0h',13,10,'$'
GUSMSGc db '‏ Onboard DRAM-Size Is $'
DRAMa   db '256 KB',13,10,'$'
DRAMb   db '512 KB',13,10,'$'
DRAMc   db '768 KB',13,10,'$'
DRAMd   db '1 MB',13,10,'$'
GUSMSGd db '‏ No (Valid) Memory Onboard',13,10,'$'

GUSNOTF db '‏ No Gravis UltraSound Found In This System :(',7,13,10,'$'

DRVINSa db '‏ GusDrive ][ Installed As Drive <'
DRVINSb db '?:>',13,10,13,10,'$'

EXEMSG  db 13,10
        db 'ױֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽ'
        db 'ֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽ¸'
        db '³°±²²ÛÛ GusDrive ][ תת (P) & (C) 1995-xxxx By נdATaנ/The CCS-Pro'
        db 'ductions ÛÛ²²±°³'
        db 'װֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽ'
        db 'ֽֽֽֽֽֽֽֽֽֽֽֽֽֽֽ¾',13,10,'$'

TYPETXT db '‏ Revision: $'
REVTXTa db 'GUS 3.7, Mixer-Chip ICS2101 (Right/Left Flip Problem)',13,10,'$'
REVTXTb db 'GUS 3.7, Mixer-Chip ICS2101',13,10,'$'
REVTXTc db 'GUS-MAX 1.8, CODEC-Mixer-Chip CS4231',13,10,'$'
REVTXTd db 'GUS-MAX 2.1, CODEC-Mixer-Chip CS4231',13,10,'$'
REVTXTe db 'Previous Release Then GUS Rev 3.7 Or No GUS',13,10,'$'
REVTXTf db 'Unknown GUS Revision Or No GUS',13,10,'$'

VOLUMEL db 'GusDrive ]['        ;Volume label
        db 9                    ;ID for volume label+ReadOnly
        db 10 dup (0)           ;Reserved
   D&T: dw 1000100101100000b    ;Time (17:11:00/8960h)
        dw 0001111101110001b    ;Date (17.11.1995/1f71h)
ENDVOLUMEL equ this byte

FMTMSGa db '‏ Format-ID Has Been Destroyed. AutoFormatting GusDrive In <'
FMTMSGb db '?:>...$'
FMTMSGc db '‏ Formatting GUS-DRAM For GusDrive In <'
FMTMSGd db '?:>...$'
FMTMSGe db 'Ok !',13,10,'$'

GUSCFG  db 01101011b            ;Hi4: Joystick/e,midi/e
                                ;Low4: Latches/e,mic-i/d,line-o/e,line-i/e

CFGTXTa db '‏ Line Input$'
CFGTXTb db '‏ Line Output$'
CFGTXTc db '‏ Microphone Input$'
CFGTXTd db '‏ Joystick Port Decode$'

ENABLT  db ' Enabled',13,10,'$'
DISABLT db ' Disabled',13,10,'$'

HELP    db 'GusDrive Extended ULTRINIT(tm) 2.23 Compatibility Mode',13,10
        db 'ִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִִ',13,10
        db 13,10
        db 'Usage: GusDrive -s -l -m -o -d(j) -e(j) -f -r',13,10,13,10
        db '       -s    = Don''t Print Version Header',13,10
        db '       -l    = Leave Line Input Enabled',13,10
        db '       -m    = Leave Mic Input Enabled',13,10
        db '       -o    = Leave Output Enabled',13,10
        db '       -d(j) = Disable Joystick',13,10
        db '       -e(j) = Enable Joystick',13,10,13,10
        db '       -f    = Format GusDrive',13,10
        db '       -i    = Initialize The Complete GUS-Memory With Zeroes'
        db 13,10
        db '       -r    = Show Full Version Number',13,10,'$'

FMTFLAG db 0                    ;0=No format,1=Format drive (EXE-mode only!)

GDDETa  db '‏ GusDrive V'
GDDETb  db '?.'
GDDETc  db '?'
GDDETd  db '? Detected As Logical Drive <'
GDDETe  db '?:>',13,10,'$'

GDRVID  db 'GusDrive'

GDNDET  db '‏ GusDrive Not Detected In Memory',13,10,'$'

UENVSN  db 'ULTRASND'           ;Name of the GUS environment variable
UENVSTa db '‏ Current Environment String: '
UENVSTb db '<not found>'        ;Contains the copy of the ULTRASND-...
        db 13,10,'$',114 dup (0)   ;...environment variable, if found

PAR1TXa db '‏ IRQ Channel 1 (GF1) will be set to '
PAR1TXb db 0,0,13,10,'$'
PAR2TXa db '‏ IRQ Channel 2 (MIDI) will be set to '
PAR2TXb db 0,0,13,10,'$'
PAR3TXa db '‏ DMA Channel 1 will be set to '
PAR3TXb db 0,0,13,10,'$'
PAR4TXa db '‏ DMA Channel 2 will be set to '
PAR4TXb db 0,0,13,10,'$'

INITa   db '‏ Initializing The GUS-Memory. Status (° = 64 kByte): $'
INITb   db ' - Done !',13,10,'$'
INITc   db '°$'

IRQLST  db 2,5,3,7,11h,12h,15h  ;GUS specific IRQ-list
DMALST  db 1,3,5,6,7            ;GUS specific DMA-list

IRQSET  db 001010110b           ;Default IRQ setting (11,12)
DMASET  db 0                    ;Default DMA setting (0,0)

DINIT   db 0

ENDDATA db 'enddata'

CODE ends

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;The 252-byte-stack

_STACK segment STACK use16 'STACK'
         db 252/6 dup ('נdATaנ')
_STACK ends

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
;End of code

end EXEMAIN                     ;EXE start address

;תתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתתת
