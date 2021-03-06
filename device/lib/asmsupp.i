
*************************************************************************
*									*
*	Copyright (C) 1985, Commodore Amiga Inc.  All rights reserved.	*
*	Permission granted for non-commercial use			*								*
*									*
*************************************************************************


*************************************************************************
*
* asmsupp.i -- random low level assembly support routines
*
* Source Control
* ------ -------
* 
* $Header: asmsupp.i,v 31.1 85/10/13 23:12:33 neil Exp $
*
* $Locker:  $
*
*************************************************************************

CLEAR	MACRO		; quick way to clear a D register on 68000
	MOVEQ	#0,\1
	ENDM

;BHS	MACRO
;	BCC.\0	\1
;	ENDM

;BLO	MACRO
;	BCS.\0	\1
;	ENDM

;EVEN	MACRO		; word align code stream
;	DS.W	0
;	ENDM

LINKSYS	MACRO		; link to a library without having to see a _LVO
	LINKLIB	_LVO\1,\2
	ENDM

CALLSYS	MACRO		; call a library without having to see _LVO
	CALLLIB	_LVO\1
	ENDM

XLIB	MACRO		; define a library reference without the _LVO
	XREF	_LVO\1
	ENDM


ABSEXECBASE equ 4   ;Absolute location of the pointer to exec.library base
_AbsExecBase equ 4   ;Absolute location of the pointer to exec.library base