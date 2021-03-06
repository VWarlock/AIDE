	include "exec/io.i"
	include "exec/types.i"
	include "exec/lists.i"
	include "exec/libraries.i"
	include "exec/devices.i"   
	include "exec/memory.i"
	include "exec/io.i"
	include "exec/tasks.i"
	include "devices/scsidisk.i"
	include "lib/mydev.i"  ;select name etc, of the device
	include "lib/atid.i"   ;This include has the macros which
	                        ;are used to access a particular
	                        ;implementation of an Amiga to ATA 
	                        ;hardware interface, such as an A500 
	                        ;side slot interface or a Parallel port
	                        ;interface.
	include "lib/ata.i"    ; defines ATA bits and commands
	include "lib/asmsupp.i"; Various helpers from Commodore
	
	XLIB AllocMem
	XLIB FreeMem


;macro INITATAINTERFACE *needs* to be executed once before this routine is ever called
;That might happen in dev.asm.
;Both drives on the ide-cable are initialised by separate calls to this
;routine.
	cnop  0,4

	PUBLIC   InitDrive
InitDrive   ;a3 = unitptr
	movem.l  d1/d2/d3/d4/a0/a1/a2/a5,-(sp)	 
	IFGE	DEBUG_DETAIL-1	
	moveq    #0,d0   
	move.b   mdu_UnitNum(a3),d0
  PRINTF 1,<'Init drive routine drive: %lx',13,10>,d0
  ENDC
	;bsr      SelectDrive
	;bne			wfc1a														 ;no drive present!	
;get memory
	moveq    #0,d4 ;d4 holds the buffer for now on
	move.l   ABSEXECBASE,a0
	move.l   #512,d0       ; we want 512 bytes for a buffer   
	move.l   #MEMF_PUBLIC!MEMF_CLEAR,d1 ;Preferable Fast mem, cleared   
	LINKSYS  AllocMem,a0
	tst.l    d0             ; memory ok?
	beq      wfc1
	move.l   d0,d4      ;save pointer
	RATABYTE TF_STATUS,d0   ;clear drive interrupt line
	cmp.b    #TRUE,mdu_auto(a3)
	bne      notauto
;get drive parameters
	move.w   #CHS_ACCESS,mdu_lba(a3)               ;presumption
	WATABYTE mdu_UnitNum(a3),TF_DRIVE_HEAD
	WATABYTE #ATA_IDENTIFY_DRIVE,TF_COMMAND   ;get drive data
	WAITNOTBSY D1
	beq      wfc1b
	moveq    #0,d0
	moveq    #0,d1
	RATABYTE TF_STATUS,d0
	;some atapi drives do NOT aboard this command: just read the CYLH/L Values
	;and.b    #ERR,d0                          ;atapi drive aborts this command
	;beq      atadrv                           ;and sets CYLH to EBh and
	RATABYTE TF_CYLINDER_HIGH,d0				 ;read Highcyl value
	RATABYTE TF_CYLINDER_LOW,d1				 ;read lowCyl value
	;check ata: d0=0 and d1=0
	cmp.b 	#0,d0
	bne		drive_test_ata_sata				 ;is it a sata-drive
	cmp.b	#0,d1 							 ;found an ata-drive
	beq		atadrv
drive_test_ata_sata
	;check sata: d0=$c3 and d1=$3c
	cmp.b 	#$C3,d0
	bne		drive_test_ata_atapi			 ;is it a atapi-drive
	cmp.b	#$3C,d1 							 ;found an sata-drive
	beq		satadrv
drive_test_ata_atapi
	;check atapi: d0=$EB and d1=$14
	cmp.b 	#$EB,d0
	bne		drive_test_ata_satapi			 ;is it a satapi-drive
	cmp.b	#$14,d1 							 ;found an atapi-drive
	beq		atapi
drive_test_ata_satapi
	;check satapi: d0=$96 and d1=$69
	cmp.b 	#$96,d0
	bne		seagate_error_drive_id ;unknown
	cmp.b	#$69,d1 							 ;found an atapi-drive
	beq		satapi
seagate_error_drive_id         ; some seagate report  1F/25 here ?!?!
	cmp.b 	#$1F,d0
	bne		wfc1c			   				 	 ;unknown
	cmp.b	#$25,d1 							 ;found an ata-drive
	beq		atadrv
	IFGE	DEBUG_DETAIL-1	
	bra		wfc1c	
	ENDC
wfc1a
	IFGE	DEBUG_DETAIL-1	
	PRINTF 1,<'SelectDrive failed!',13,10>
	bra    wfc1
	ENDC
wfc1b
	IFGE	DEBUG_DETAIL-1	
  PRINTF 1,<'ATA_IDENTIFY_DRIVE failed! ',13,10>
	bra    wfc1
	ENDC
wfc1c
	IFGE	DEBUG_DETAIL-1	
	PRINTF 1,<'Unknown drive type %ld %ld!',13,10>,d0,d1
	bra    wfc1
	endC
wfc1d
	IFGE	DEBUG_DETAIL-1	
	PRINTF 1,<'IDENTIFY_PACKET_DEVICE failed! ',13,10>
	bra    wfc1
	ENDC
wfc1e
	IFGE	DEBUG_DETAIL-1	
	PRINTF 1,<'Got no DRDY from IDENTIFY_xx!',13,10>
	bra    wfc1	
	ENDC
wfc1
	move.w   #UNKNOWN_DRV,mdu_drv_type(a3)
	bra      kr2
satapi
	move.w   #SATAPI_DRV,mdu_drv_type(a3)
	bra		wfc2
atapi
	move.w   #ATAPI_DRV,mdu_drv_type(a3)
wfc2
	WATABYTE mdu_UnitNum(a3),TF_DRIVE_HEAD
	WATABYTE #IDENTIFY_PACKET_DEVICE,TF_COMMAND  ;get atapi drive data
	WAITDRQ  D0
	beq      wfc1d
	RATABYTE TF_STATUS,d0               ;clear interrupt line
	move.w   #LBA28_ACCESS,mdu_lba(a3)  ; this does not limit DVD-Drives! The read/write routine should chop al access <48bit to lba28
	;add.b	   #L,mdu_UnitNum(a3)    ;set the LBA-bit in the unit number
	clr.l    mdu_sectors_per_track(a3)
	clr.l    mdu_heads(a3)
	clr.l    mdu_cylinders(a3)
	bra      kr3
satadrv
	move.w   #SATA_DRV,mdu_drv_type(a3)  ;sata drive
	bra      kr3
atadrv
	move.w   #ATA_DRV,mdu_drv_type(a3)  ;ata drive
kr3
	WAITDRQ	D0
	beq      wfc1e
	move.l   d4,a5                  ;get identify data
	move.l	#127,d0
	move.l   #TF_DATA,a0
kr3data
	move.l   (a0),(a5)+
	dbra     d0,kr3data
	move.l   d4,a5                  

	;IF Y=0 SWAP BYTES IN WORD BECAUSE AMIGA DATA0..7 IS DRIVE DATA8.15
	IFEQ Y,0
	   move.l   A5,A0       ;buffer start
	   movem.l  d1-d2,-(sp) ;d1-d2 to stack
	   move.w   #256-1,d0   ;move.word because dbra uses 16bits of register
lk    move.w   (a0),d1
	   move.w   d1,d2
	   lsl.w    #8,d1
	   lsr.w    #8,d2
	   and.w    #$ff,d2
	   or.w     d2,d1
	   move.w   d1,(a0)+
	   dbra     d0,lk
	   movem.l  (sp)+,d1-d2 ;restore d1-d2
	ENDC

	move.l   d4,a5   ;copy serial number to internal info buffer
	add.l    #20,a5			
	lea      mdu_ser_num(a3),a0
	move.b   #20,d0				
	bsr      CopyString	

	move.l   d4,a5
	add.l    #46,a5
	lea      mdu_firm_rev(a3),a0  ;copy firm. revision to int. buffer 8byte
	move.b   #8,d0				
	bsr      CopyString	

	;Sometimes we fall through here and still think this is a ATA-(Slave)Drive 
	;but there is no drive! So do the following:
	;Sanity check: the model MUST only consist of ASCII-characters between $20 and $7E
	;this check is done in the CopyString routine!

	move.l   d4,a5
	add.l    #54,a5  ;here is the model number
	lea      mdu_model_num(a3),a0 ;copy model number to int. buffer 40 bytes
	move.b   #40,d0				
	bsr      CopyString	
	cmp.l    #0,d0
	bne      wfc1	     ;Crapy ASCII: unknown drive!

	moveq    #0,d0
	move.w   mdu_drv_type(a3),d0
	cmp.w    #ATA_DRV,mdu_drv_type(a3)
	beq      noeritd
	cmp.w    #SATA_DRV,mdu_drv_type(a3)
	beq      noeritd
	WATABYTE #0,TF_FEATURES       ;for atapi cdrom with
	bra      kr2
noeritd     ; ATA disk /SATA disk
	move.l   d4,a5
	moveq    #0,d0                ; clear upper 16 bit!
	move.w   1*2(a5),d0           ;Word 1 Number of logical cylinders
	move.l   d0,mdu_cylinders(a3) ;store to internal buffer
	move.w   6*2(a5),d0           ;Word 6 Default Translation sectors
	move.l   d0,mdu_sectors_per_track(a3)  ;store to internal buffer
	move.w   3*2(a5),d0           ;Word 3 Default Translation Mode number of heads
	move.l   d0,mdu_heads(a3)     ;store to internal buffer
	move.b	#1,mdu_SectorBuffer(a3)
	move.w   47*2(A5),d0          ;WRITE/READ Multiple capabilities
	cmp.l	#1,d0				 ;multi sector supportet?
	bra		multiple_sector_dis  ; not set
	move.b	d0,mdu_SectorBuffer(a3)
multiple_sector_dis
	move.w   49*2(A5),d0          ;Word 49 Capabilities
	and.w    #$200,d0             ;Bit 9 1=LBA Supported
	beq      nolba
	move.w   61*2(a5),d0          ;Words 60-61 # of user addressable sectors (LBA)
	swap   d0
	or.w     60*2(a5),d0
	;and.l    #$0FFFFFFF,d0        ;allow only 128GB = LBA28-access!
	CMP.l    #$0FFFFFFF,d0        ;allow only 128GB = LBA28-access!
	BLE.s    lba28ok
	MOVE.l   #$0FFFFFFF,d0
lba28ok:	
	move.l   d0,mdu_numlba(a3)    ;store to internal buffer
	beq      nolba                ;propably no lba support if no lba sectors
	MOVE.w   #LBA28_ACCESS,mdu_lba(a3)    ;store to internal buffer
	or.b     #L,mdu_UnitNum(a3);set the LBA-bit in the unit number
	move.w   83*2(A5),d0          ;Word 83 Capabilities * LBA48 support check
	and.w    #$400,d0             ;Bit 10 1=LBA48 Supported
	beq		   endauto				 ; stay at LBA28
;	MOVE.w   103*2(a5),d0         ;4th word LBA48
;	SWAP   d0
;	OR.w     102*2(a5),d0		 ;3rd word LBA48
;	TST.l		 D0
;	beq			 lba32				 ;no lba48?!?-> goto lba32
	;currently I support only "LBA32"
;	MOVE.l   #$FFFFFFFF,D0  ;store max value to size register
;	BRA.s		   lba48fine				 
lba32:	
	;now the lower 32 bits
	MOVE.w   101*2(a5),d0         ;2nd word LBA48
	SWAP   d0
	OR.w     100*2(a5),d0		 ;1st word LBA48
;	TST.l		 D0
;	bne			 lba48fine				 ;something
	;currently I support only "LBA32"
;	MOVE.l   #$FFFFFFFF,D0  ;store max value to size register
lba48fine:
	AND.L    #~(3),D0							;make the blocks devidable by 4!
	MOVE.l   d0,mdu_numlba48(a3)  ;store to internal buffer
	AND.l		 #$F0000000,D0         ;>128GB?
	beq		endauto				 ;LBA48 supported but <128GB: stay at LBA28!
	MOVE.l   mdu_numlba48(a3),D0  ;restore from internal buffer
	MOVE.l   d0,mdu_numlba(a3)    ;store to internal buffer
	MOVE.w   #LBA48_ACCESS,mdu_lba(a3)    ;store to internal buffer	   
	BRA      endauto
nolba                            ;Then its CHS
	move.w   #CHS_ACCESS,mdu_lba(a3)   ;store to internal buffer
	or.b     #$A0,mdu_UnitNum(a3)
	;Conner Peripherals CP3044 lies about its default translation mode
	lea      CP3044txt(pc),a0
	move.l   a5,a1
	add.l    #$50,a1
ko move.b   (a0)+,d0
	beq      wascp3044
	move.b   (a1)+,d1
	cmp.b    d0,d1
	beq      ko
;not cp3044
	bra      endauto
wascp3044
	move.l   #4,mdu_heads(a3)
	move.l   #40,mdu_sectors_per_track(a3)
	bra      endauto
endauto
notauto
	RATABYTE TF_STATUS,d0               ;clear interrupt line
	cmp.w    #ATA_DRV,mdu_drv_type(a3)
	beq      setupata
	cmp.w    #SATA_DRV,mdu_drv_type(a3)
	beq      setupata
	bra		kr2
setupata
  ;fill the scsi-inquiery packets
  lea      mdu_model_num(a3),a2
	lea      8+mdu_EmulInquiry(a3),a0
	move.l   (a2)+,(a0)+
	move.l   (a2)+,(a0)+
	lea      mdu_ser_num(a3),a2
	;lea      16+mdu_EmulInquiry(a3),a0
	move.l   (a2)+,(a0)+
	move.l   (a2)+,(a0)+
	move.l   (a2)+,(a0)+
	move.l   (a2),(a0)
  ;fill the scsi-ModeSende Packet 3/4 data
  lea      mdu_EmulMSPage3(a3),a2
	move.l   mdu_sectors_per_track(a3),d0
	move.w   d0,14(a2)
	lea      mdu_EmulMSPage4(a3),a2
	move.l   mdu_cylinders(a3),d0
	move.l   d0,d1
	lsr.l    #8,d0
	move.w   d0,6(a2)
	move.w   d0,10(a2)
	move.w   d0,18(a2)
	move.b   d1,8(a2)
	move.b   d1,12(a2)
	move.b   d1,20(a2)
	move.w   d1,14(a2)
	swap     d1
	move.b   d1,13(a2)
	move.l   mdu_heads(a3),d0
	move.b   d0,9(a2)

;   cmp.l    #16514064,mdu_numlba(a3)		; devices with less blocks should support the following chs translation
;   bge			kr2
;	move.l   mdu_sectors_per_track(a3),d0  ;send to drive which CHS translation
;	WATABYTE d0,TF_SECTOR_COUNT         ;to use - important to drives with
;	move.l   mdu_heads(a3),d0           ;LBA support
;	subq.b   #1,d0
;	or.b     mdu_UnitNum(a3),d0
;	btst.b   #MDUB_SLAVE,mdu_UnitNum(a3)
;	beq      pis1
;	bset     #MDUB_SLAVE,d0
;pis1
;	WATABYTE d0,TF_DRIVE_HEAD
	;DLY400NS
	;WAITREADYFORNEWCOMMAND D1;,D2 
;	WATABYTE #ATA_INITIALIZE_DRIVE_PARAMETERS,TF_COMMAND  ;get drive data
;	WAITNOTBSY D1
kr2
	move.l   d4,d1 ;is there a pointer in buffer?
	tst.l    d1
	beq kr21
	
	move.l  ABSEXECBASE,a0
	move.l   d4,a1
	move.l   #512,d0
	LINKSYS FreeMem,a0
	
kr21:
  PRINTF 1,<'Init drive routine ended ',13,10>

	move.l   #0,d4
	movem.l  (sp)+,d1/d2/d3/d4/a0/a1/a2/a5
	rts

CopyString
;A0: destination
;A5: source
;D0: maxlen
loopcopy
	cmp.b    #0,(a5)
	;null termination is OK
	beq      copyendgood
	cmp.b    #$20,(a5)
	blt      copyendbad	     ;Crapy ASCII: unknown drive!
	cmp.b    #$7E,(a5)
	bgt      copyendbad	     ;Crapy ASCII: unknown drive!	
	move.b   (a5)+,(a0)+
	subq.b	#1,d0
	bne		loopcopy
copyendgood
	move.b   #0,(a0)				;null termination of string
  moveq    #0,d0
copyendbad
  rts
    
	Public ResetIDE
;SoftwareReset IDE-BUS
ResetIDE
	;movem.l  d0,-(sp)
	WATABYTE  #nIEN+SRST,TF_DEVICE_CONTROL ;assert reset and INTERRUPT
	move.l	  #16000,d0 ;wait 
rstwait1:
	DLY5US
	subq.l    #1,D0
	bne.s		  rstwait1
	;release reset
	WATABYTE  #nIEN,TF_DEVICE_CONTROL ;assert reset and INTERRUPT
	move.l	  #120000,d0 ;wait 200ms
rstwait2:
	tst.b	 $bfe301 ;slow CIA access cycle takes 12-20 7MHz clocks: 1.7us - 2.8us
	subq.l    #1,D0
	bne.s 	  rstwait2
	;movem.l  (sp)+,d0
  rts
  
  ;perform safe switch to act_drv drive
	PUBLIC	SelectDrive
SelectDrive:
	moveq   #0,d0
	move.b	mdu_UnitNum(a3),d0
	WATABYTE d0,TF_DRIVE_HEAD
	DLY400NS ;Other sources suggest 5 times TF_STATUS read instead a 400ns wait
	;RATABYTE	TF_STATUS,d0				; clear interrupt line
	;check if it worked: write something to the sector count and read it back
	;WATABYTE  #$5A,TF_SECTOR_NUMBER
	;RATABYTE	TF_SECTOR_NUMBER,d0				
	;cmp.b	  #$5A,d0
	;beq		sdr4	
	;move.l	#1,d0					 ; clear zero flag
sdr4
	move.l	#0,d0					 ; clear zero flag
	rts	
	
	cnop  0,4
CP3044txt   dc.b  'CP3044 ',0    ; 8 bytes = 2 longwords ->alligned!
	cnop  0,4
	
	Public EndCodeInit
EndCodeInit:
	END

