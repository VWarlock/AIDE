   SECTION   section
   include "exec/types.i"
   include "exec/nodes.i"
   include "exec/lists.i"
   include "exec/libraries.i"
   include "exec/devices.i"
   include "exec/io.i"
   include "exec/alerts.i"
   include "exec/initializers.i"
   include "exec/memory.i"
   include "exec/resident.i"
   include "exec/ables.i"
   include "exec/errors.i"
   include "exec/tasks.i"
   include "devices/scsidisk.i"
 	 include "devices/hardblocks.i"
   include "libraries/expansion.i"
   include "libraries/configvars.i"
   include "libraries/configregs.i"
   include "libraries/expansionbase.i"
   include "libraries/filehandler.i"
   ;Note that the next ASSIGNs ending with : need to be assigned
   ;outside of this assembly source file, eg. in compilation scripts.
   ;These are AmigaDos "links" to some certain file.
   include "/lib/asmsupp.i";Various helper macros made by Commodore
   INCLUDE "IDE_BASE_ADDRESS.i"
   include "/lib/mydev.i"  ;select name etc, of the device
   ;include "/lib/myscsi.i" ;
   include "/lib/ata.i"    ;ATA commands and other ATA codes
   ;include "/lib/atid.i"   ;This include has the macros which
         ;are used to access a particular
         ;implementation of an Amiga to ATA 
         ;hardware interface, such as an A500 
         ;side slot interface or a Parallel port
         ;interface.
   include "/lib/bootinfo.i";Structure for boot infos
   include "/debug/debug-wrapper.i"

   XLIB	AllocMem
   XLIB	FreeMem
   XLIB	MakeDosNode
   XLIB	AddDosNode
   XLIB	OpenLibrary
   XLIB	CloseLibrary
   XLIB	FindResident
   XLIB	InitResident
   XLIB AddBootNode
   XLIB	Enqueue
   XLIB	Permit
   XLIB	Forbid
   XLIB	FindName
   XLIB FindResident
   XLIB InitResident
   XLIB AllocConfigDev
   XLIB AddConfigDev
   XREF ATARdWt

		IFND	DEBUG_DETAIL
DEBUG_DETAIL	SET	0	;Detail level of debugging.  Zero for none.
		ENDC

   moveq  #-1,d0 
   rts          ;Return in case this code was called as a program

romtag:
   dc.w    RTC_MATCHWORD
   dc.l    romtag
   dc.l    endcode
   dc.b    RTW_COLDSTART
   dc.b    BD_VERSION
   dc.b    NT_DEVICE
   dc.b    5
   dc.l    bootname
   dc.l    bootid
   dc.l    initRoutine

bootname:
   dc.b    'anyboot',0
bootid:
   dc.b    'anyboot 1.0  (10 Jul 2015)',13,10,0
		CNOP	0,4
   
initRoutine:
   movem.l d1-d7/a0-a6,-(SP)
   PRINTF 1,<'Start',13,10>
   move.l   d0,devicebase
		
   ; Get 512 bytes of memory for sector buffer
   move.l  #BLOCKSIZE,d0
   moveq.l #MEMF_ANY,d1
   move.l  ABSEXECBASE,a6
   LINKSYS  AllocMem,a6
   tst.l   d0
   beq     close_and_dealloc
   move.l  d0,buffermem
   
   ;PRINTF 1,<'alloc %ld bytes for blockbuffer at %lx',13,10>,#BLOCKSIZE,D0
   

   ; Get 512 bytes of memory for rdb buffer
   move.l  #BLOCKSIZE,d0
   moveq.l #MEMF_ANY,d1
   move.l  ABSEXECBASE,a6
   CALLSYS  AllocMem
   tst.l   d0
   beq     close_and_dealloc
   move.l  d0,rdbmem

   ; get mem for parameter packet
   move.l  #MyParmPkt_Sizeof,d0
   moveq.l #MEMF_ANY,d1
   CALLSYS  AllocMem
   tst.l   d0
   beq     close_and_dealloc
   move.l  d0,parametermem
   ;PRINTF 1,<'alloc %ld bytes for parameter packet at %lx',13,10>,#MyParmPkt_Sizeof,D0
      
   ; get mem for io handler
   move.l  #IOSTD_SIZE,d0
   moveq.l #MEMF_ANY,d1
   CALLSYS  AllocMem
   tst.l   d0
   beq     close_and_dealloc
   move.l  d0,iohandler
   ;PRINTF 1,<'alloc %ld bytes for parameter packet at %lx',13,10>,#IOSTD_SIZE,D0


   ;find the device
   lea	bootdevicename,a1	; the device name to look for
   lea	DeviceList(a6),a0	; in Device-Liste suchen.
   CALLSYS	FindName   
   ;PRINTF 1,<'Seach in device list for %s resulted in %lx',13,10>,A1,D0
   tst.l	d0   
   bne device_present
   
   ;device not loaded: find the resident structure
   lea	bootdevicename,a1	; the device name to look for
   CALLSYS FindResident   
	 ;PRINTF 1,<'Find Resident resulted in %lx',13,10>,D0
   tst.l	d0   
   beq     close_and_dealloc
   
	 ;init the resident structure
	 moveq.l #0,d1 ;resident structure in rom 
	 move.l D0,A1
	 
	 CALLSYS InitResident
   
	 ;PRINTF 1,<'InitResident resulted in %lx',13,10>,D0
	 beq     close_and_dealloc
   
device_present:
   move.l  d0,residentstructure
   ; Open expansion.library
   lea     expname,a1
   moveq   #0,d0
   move.l  ABSEXECBASE,a6
   CALLSYS  OpenLibrary
   tst.l   d0
   beq     close_and_dealloc
	 move.l  d0,expansionlib
   
   ;PRINTF 1,<'Opened expansion lib: %lx',13,10>,D0
   move.l  d0,a6

   ;now build a fake config dev!
   CALLSYS AllocConfigDev
   ;PRINTF 1,<'Created Config dev: %lx',13,10>,D0
   move.l  d0,configdev
   beq     close_and_dealloc
   ;init the ConfigDev
   move.l  d0,a0
   lea.l   fakebootrom,a1
   move.l  a1,cd_Rom+er_Reserved0c(a0) ;save the diag entry
   move.l  #IDE_BASE_ADDRESS,cd_BoardAddr(a0) ;save the board adress
   move.l  #65536,cd_BoardSize(a0) ;store the board size
   move.b  #ERTF_DIAGVALID+ERT_ZORROII,cd_Rom+er_Type(a0) ; this makes the thing autoboot
   move.w  #2588,cd_Rom+er_Manufacturer(a0) ;a1k org :D
   move.b  #123,cd_Rom+er_Product(a0)
   CALLSYS AddConfigDev ;add it to the system


   move.l  #0,unitnum

next_unit:
	 ;now open the device!
   move.l  unitnum,d0
	 PRINTF 1,<'Opening unit %lx',13,10>,d0
	 bsr open_device
   ;check result
   cmp.b  #IOERR_OPENFAIL,D0   
   beq close_and_dealloc
   move.l  iohandler,a1
   move.l  IO_UNIT(a1),unitptr

   

   ; Read rdb block here!
   moveq  #0,d4
   move.l #0,d0  
   move.l rdbmem,a0
   move.l #IDNAME_RIGIDDISK,d6

search_rdb:
   cmp.l  #MAX_BLOCK_SEARCH_RDB,d4
   bge.l  more_units  ;nothing found!
   move.l rdbmem,a0
   PRINTF 1,<'Searching for rdb at block %ld, offset %lx',13,10>,d4,d0
   bsr    read_block
   bne    more_units ;on error go to next unit
   ;theoretically i have to checksum it...
   move.l rdb_ID(a0),d5
   ;PRINTF 1,<'block id: %lx, expected: %lx',13,10>,d5,d6
   cmp.l  d5,d6
   beq    rdb_found   
   addi.l #512,d0  
   addi.l #1,d4
   bra    search_rdb

rdb_found:  
   PRINTF 1,<'Found a rdb at block %ld',13,10>,d4
   move.l rdbmem,a0 
   move.l #IDNAME_PARTITION,d6
   move.l rdb_PartitionList(a0),d0 ;there is our first partition
   move.l buffermem,a0 ;work on buffermem now!
nextpartition:
   PRINTF 1,<'Loading partition in block: %lx',13,10>,d0
   lsl    #8,d0 ;multiply by 512
   lsl    #1,d0
   bsr    read_block
   bne    more_units ;on error go to next unit
   move.l pb_ID(a0),d5
   cmp.l  d5,d6
   beq    found_partition 
   bra    more_units
      
found_partition   
   lea.l	pb_DriveName(a0),a1	;get the drive name (BSTR)
	 clr.w	d1
	 move.b	(a1)+,d1		;null terminate it (for safety)
	 clr.b	0(a1,d1.w)
   ; TODO: now check for dos-name duplicates   
   lea.l	pb_DriveName(a0),a1	;get the drive name (BSTR)
   move.b	(a1)+,d1            ;BSTR->ASTR
   PRINTF 1,<'Found Dos name: %s, length %lx',13,10>,a1,d1
   bsr    patch_dosname
   bne    close_and_dealloc ; error in name patch
   
   move.l parametermem,a3
   lea.l	pb_DriveName(a0),a1	;get the drive name (BSTR)
   move.b	(a1)+,d1            ;BSTR->ASTR
   move.l	a1,pp_dosName(a3)
   lea		bootdevicename,a1
   move.l	a1,pp_execName(a3)
   move.l unitptr,a1
   move.l mdu_UnitNum(a1),d1
   move.l	d1,pp_unitNumber(a3)
   move.l	pb_Flags(a0),pp_flags(a3)
   ;move.l	#16,pp_paramSize(a3)     ; 16 longwords comming
   lea.l	pb_Environment(a0),a0    ; start of origin
   lea.l  pp_paramSize(a3),a3      ; start of destination (first word after flag)
   moveq  #16,d0                   ; 17 long word comming one less for dbra
copy_param_packet:
   move.l (a0)+,(a3)+
   dbra   d0,copy_param_packet     ; 
   ;restore buffers
   move.l buffermem,a0 
   move.l parametermem,a3
   
   ;bsr print_param_packet  
   btst.b   #PBFB_NOMOUNT,pp_flags+3(a3) ;+3 for long to byte
   bne      preparenextpartition   

;   bra close_and_dealloc
;   move.l	#128,pp_blockSize(a3)    ; 128*4=512 bytes in long words
;   move.l	#0,pp_sectorOrigin(a3)    ;leave 0
;   move.l	#1,pp_surfaces(a3) ;
;   move.l	#1,pp_sectorsPerBlock(a3) 		;leave 1
;   move.l	#288,pp_blocksPerTrack(a3)
;   move.l	#2,pp_reservedBlocks(a3)
;   move.l	#0,pp_preface(a3); leave 0
;   move.l	#0,pp_interleave(a3)
;   move.l	#2,pp_lowCyl(a3)
;   move.l	#433,pp_highCyl(a3)
;   move.l	#300,pp_numBuffer(a3)
;   move.l	#MEMF_ANY,pp_BufferMemType(a3)
;   move.l	#$00FFFFFF,pp_maxTransfer(a3)
;   move.l	#$7FFFFFFE,pp_mask(a3)   
;   move.l	#20,pp_bootPrio(a3)
;   move.l	#$444F5301,pp_dosType(a3)

   ; Create the DOS node.
   move.l  a3,a0
   CALLSYS MakeDosNode
   tst.l   d0
   beq     close_and_dealloc
   ;PRINTF 1,<'Made DosNode: %lx',13,10>,D0
   move.l  d0,devicenode ; move the device node to mem
   move.l parametermem,a3 ;first move parampacket to a3 (again?!?)
   ;set d0/d1: priority and startproc
   move.l   pp_bootPrio(a3),d0			this priority
   moveq.l	#ADNF_STARTPROC,d1	StartProc = true
   ;put the DeviceNode from mem in A0
   move.l   devicenode,a0 
   move.l   #0,a1
   btst.l   #PBFB_BOOTABLE,pp_flags+3(a3)
   beq      add_node   ; no boot flag
   ;load the ConfigDev in a1
   move.l  configdev,a1
add_node:
   CALLSYS  AddBootNode	
	 ;PRINTF 1,<'AddBootNodeResult %lx',13,10>,d0
preparenextpartition:
   move.l buffermem,a0
   move.l pb_Next(a0),d0
   PRINTF 1,<'Next partition in block: %lx',13,10>,d0
   cmp.l  #$FFFFFFFF,d0
   bne    nextpartition
more_units:   
   bsr    close_device
   cmp.l  #10,unitnum
   beq    close_and_dealloc
   move.l #10,unitnum
   bra    next_unit
   

close_and_dealloc:
   move.l  ABSEXECBASE,a6
	 tst.l	 expansionlib
	 beq     dealloc_exit1
   move.l  expansionlib,a1
   CALLSYS CloseLibrary
   ;PRINTF 1,<'Closed expansion lib at %lx',13,10>,a1
   move.l  #0,expansionlib
dealloc_exit1:
   tst.l   buffermem ;mem allocated?
   beq     dealloc_exit2
   move.l  buffermem,a1
   move.l  #BLOCKSIZE,d0
   ;PRINTF 1,<'Free %ld byte buffer mem at %lx',13,10>,d0,a1
   LINKSYS FreeMem,a6
   move.l #0,buffermem
dealloc_exit2:
   tst.l   parametermem ;mem allocated?
   beq     dealloc_exit3
   move.l  parametermem,a1
   move.l  #MyParmPkt_Sizeof,d0
   ;PRINTF 1,<'Free %ld byte param mem at %lx',13,10>,d0,a1
   LINKSYS FreeMem,a6   
   move.l #0,parametermem
dealloc_exit3:
   tst.l   bootnodemem ;mem allocated?
   beq     dealloc_exit4
   move.l  bootnodemem,a1
   move.l  #BootNode_SIZEOF,d0
   ;PRINTF 1,<'Free %ld byte boot node mem at %lx',13,10>,d0,a1
   LINKSYS FreeMem,a6   
   move.l #0,bootnodemem   
dealloc_exit4:
   tst.l   iohandler ;mem allocated?
   beq     dealloc_exit5
   move.l  iohandler,a1
   move.l  #IOSTD_SIZE,d0
   ;PRINTF 1,<'Free %ld byte iohandler mem at %lx',13,10>,d0,a1
   LINKSYS FreeMem,a6   
   move.l #0,iohandler   
dealloc_exit5:
   tst.l   rdbmem ;mem allocated?
   beq     dealloc_exit2
   move.l  rdbmem,a1
   move.l  #BLOCKSIZE,d0
   ;PRINTF 1,<'Free %ld byte buffer mem at %lx',13,10>,d0,a1
   LINKSYS FreeMem,a6
   move.l #0,rdbmem
bomb:       
   ;bsr     freedosnode
   move.l   devicebase,d0
   PRINTF 1,<'End: returning %lx',13,10>,D0
   movem.l (SP)+,d1-d7/a0-a6
   rts

;freedosnode:
;   tst.l   devicenode
;   beq     nothingtofree
;   movem.l a1/a6,-(SP)   
;   move.l  #DeviceNode_SIZEOF,d0
;   move.l  devicenode,a1
;   move.l  ABSEXECBASE,a6
;   LINKSYS FreeMem,a6   
;   move.l  #0,devicenode   
;   movem.l (SP)+,a1/a6
;nothingtofree;
;   rts

open_device:
   movem.l d1/a1/a6,-(SP)
   ;device in a6
   move.l residentstructure,a6
   ;unitnum in d0
   move.l unitnum,d0
   ;flags in d1
   move.l #0,d1
   ;iohandler in a1
   move.l  iohandler,a1
   CALLLIB LIB_OPEN
   ;PRINTF 1,<'Open returned %lx',13,10>,D0
   movem.l (SP)+,d1/a1/a6
   rts

close_device:
   movem.l a1/a6,-(SP)
   ;device in a6
   move.l residentstructure,a6
   ;iohandler in a1
   move.l  iohandler,a1
   CALLLIB LIB_CLOSE
   ;PRINTF 1,<'Close returned %lx',13,10>,D0
   movem.l (SP)+,a1/a6
   rts


patch_dosname: 
   movem.l d1/a0/a1/a6,-(SP)    
   PRINTF  1,<'Patching string %s',13,10>,a1
   ;first find the end of the string:
   moveq   #0,d1     ;look from start
test_string:
   cmp.b   #0,0(a1,d1.w)
   beq     end_of_string_found
   addq.w  #1,d1
   cmp.w   #MAXLENGTH,d1
   bls     test_string
   PRINTF  1,<'Name too long: %d',13,10>,d1
   moveq   #1,d0 ;anything not null is an error!
   bra     end_patch_dosname 
end_of_string_found

   PRINTF  1,<'String %s has a length of %ld',13,10>,a1,d1
   ;name to look for is in a1!
   move.l  ABSEXECBASE,a6
   lea	   eb_MountList(a6),a0 ;see if we allready have this name in the mountlist   
patch_dosname_again:
   CALLSYS FindName
   PRINTF  1,<'FindName resulted in %ld',13,10>,d0
   tst.l   d0
   beq     end_patch_dosname ; no dups = all ok!
   ;we have to modify this name d1 holds the end of the string!
   ;add a 'x' to the name
   move.b	 #"x",0(a1,d1.w)   
   clr.b	 1(a1,d1.w); null terminate!
   addq.w  #1,d1
   PRINTF  1,<'New name is %s, length %d',13,10>,a1,d1
   cmp.w   #MAXLENGTH,d1
   ble     patch_dosname_again ;max length reached?
   PRINTF  1,<'Name too long: %d',13,10>,d1
   moveq   #1,d0 ;anything not null is an error!
end_patch_dosname:
   movem.l (SP)+,d1/a0/a1/a6
   rts

;print_param_packet:
;   movem.l d0/a0/a3,-(SP)
;   move.l parametermem,a3
;   move.l	pp_execName(a3),a0
;   PRINTF 1,<'Device: %s',13,10>,a0
;   move.l  pp_dosName(a3),a0
;   PRINTF 1,<'Dos Name: %s',13,10>,a0
;   move.l pp_unitNumber(a3),d0
;   PRINTF 1,<'Unit: %ld',13,10>,d0
;   move.l pp_flags(a3),d0
;   PRINTF 1,<'Flags: %ld',13,10>,d0
;   move.l pp_paramSize(a3),d0
;   PRINTF 1,<'Environment size: %ld',13,10>,d0
;   move.l pp_blockSize(a3),d0
;   PRINTF 1,<'Block size: %ld',13,10>,d0
;   move.l	pp_sectorOrigin(a3),d0
;   PRINTF 1,<'Sector origin: %ld',13,10>,d0
;   move.l	pp_surfaces(a3),d0
;   PRINTF 1,<'Surfaces: %ld',13,10>,d0
;   move.l	pp_sectorsPerBlock(a3),d0
;   PRINTF 1,<'Sectors per block: %ld',13,10>,d0
;   move.l	pp_blocksPerTrack(a3),d0
;   PRINTF 1,<'Blocks per track: %ld',13,10>,d0
;   move.l	pp_reservedBlocks(a3),d0
;   PRINTF 1,<'Reserved blocks: %ld',13,10>,d0
;   move.l	pp_preface(a3),d0
;   PRINTF 1,<'Preface: %ld',13,10>,d0
;   move.l	pp_interleave(a3),d0
;   PRINTF 1,<'Interleave: %ld',13,10>,d0
;   move.l	pp_lowCyl(a3),d0
;   PRINTF 1,<'Low cylinder: %ld',13,10>,d0
;   move.l	pp_highCyl(a3),d0
;   PRINTF 1,<'High cylinder: %ld',13,10>,d0
;   move.l	pp_numBuffer(a3),d0
;   PRINTF 1,<'Num Buffers: %ld',13,10>,d0
;   move.l	pp_BufferMemType(a3),d0
;   PRINTF 1,<'Buffer type: %ld',13,10>,d0
;   move.l	pp_maxTransfer(a3),d0
;   PRINTF 1,<'Max transfer: %lx',13,10>,d0
;   move.l	pp_mask(a3),d0
;   PRINTF 1,<'Mask: %lx',13,10>,d0
;   move.l	pp_bootPrio(a3),d0
;   PRINTF 1,<'Boot prio: %ld',13,10>,d0
;   move.l	pp_dosType(a3),d0
;   PRINTF 1,<'Dostype: %lx',13,10>,d0
;   movem.l (SP)+,d0/a0/a3
;   rts

clear_block
   movem.l d0/a0,-(SP)
   PRINTF 1,<'Clearing address %lx',13,10>,a0
   moveq #0,d0
clear_block_loop:   
   move.l	#0,(a0)+
   addq.w #4,d0
   cmp.w  #BLOCKSIZE,d0
   blt    clear_block_loop
   PRINTF 1,<'Cleared: %lx bytes, end adress: %lx',13,10>,d0,a0
   movem.l (SP)+,d0/a0
   rts

read_block ;blocknumber in d0, buffer in a0, returns 0 if read is not successfull
   ;PRINTF 1,<'Status pre read:',13,10>
   ;PRINTF 1,<'D0: %8lx D1: %8lx D2: %8lx D3: %8lx ',13,10>,d0,d1,d2,d3
   ;PRINTF 1,<'D4: %8lx D5: %8lx D6: %8lx D7: %8lx ',13,10>,d4,d5,d6,d7
   ;PRINTF 1,<'A0: %8lx A1: %8lx A2: %8lx A3: %8lx ',13,10>,a0,a1,a2,a3
   ;PRINTF 1,<'A4: %8lx A5: %8lx A6: %8lx SP: %8lx ',13,10>,a4,a5,a6,sp

   movem.l d0-d7/a0-a6,-(SP)  
   bsr    clear_block ;clear old result first!

   ;ATARdWt:
   ;a0 IO data address
   ;a2 #READOPE/#WRITEOPE  operation is either read or write
   ;a3 unitptr
   ;d0 io length
   ;d1 io offset low
   ;d5 io offset high  !NEW!!
   ;d2 unit number 
   move.l unitptr,a3
   move.l mdu_UnitNum(a3),d2
   move.l #READOPE,a2
   move.l #0,d5
   move.l d0,d1
   move.l #512,d0
   ;PRINTF 1,<'Call ATRdWt',13,10>
   bsr ATARdWt
   ;PRINTF 1,<'Returning reading block with %lx',13,10>,d0   

   movem.l (SP)+,d0-d7/a0-a6
   ;PRINTF 1,<'Status post read:',13,10>
   ;PRINTF 1,<'D0: %8lx D1: %8lx D2: %8lx D3: %8lx ',13,10>,d0,d1,d2,d3
   ;PRINTF 1,<'D4: %8lx D5: %8lx D6: %8lx D7: %8lx ',13,10>,d4,d5,d6,d7
   ;PRINTF 1,<'A0: %8lx A1: %8lx A2: %8lx A3: %8lx ',13,10>,a0,a1,a2,a3
   ;PRINTF 1,<'A4: %8lx A5: %8lx A6: %8lx SP: %8lx ',13,10>,a4,a5,a6,sp

   rts

devicebase: dc.l 0
residentstructure: dc.l 0
buffermem: dc.l 0
rdbmem: dc.l 0
parametermem: dc.l 0
bootnodemem: dc.l 0
configdev: dc.l 0
expansionlib: dc.l 0
devicenode: dc.l 0
iohandler: dc.l 0
unitptr:   dc.l 0
unitnum:   dc.l 0

   ; Fake ConfigDev and Diagnostic ROM structure.
fakebootrom:
   dc.b    DAC_WORDWIDE+DAC_CONFIGTIME
   dc.b    0
   dc.w    0
   dc.w    0
   dc.w    bootcode-fakebootrom
   dc.w    bootdevicename-fakebootrom
   dc.w    0 ;da_Reserved01
   dc.w    0 ;da_Reserved02

   
; DOS boot code.
bootcode:
   lea     dosname(pc),a1
   CALLSYS FindResident
   tst.l	d0			;did we find it?
   beq.s	BootedMe		;no
   move.l  d0,a0
   move.l  RT_INIT(a0),a0
   jsr     (a0)
BootedMe:
   rts
   CNOP 0,4
dosname:
   dc.b    'dos.library',0
		CNOP	0,2
endcopy:
bootdevicename:
   dc.b    'ide.device',0
bootdosname:
   dc.b    'DH0',0
expname:    dc.b    'expansion.library',0

endcode:
   end
