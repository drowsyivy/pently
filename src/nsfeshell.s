;
; Pently audio engine
; NSF player shell
;
; Copyright 2012-2017 Damian Yerrick
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;

; Requires the appropriate -titles.inc (generated by pentlyas.py
; --write-inc something-titles.inc) to be prepended.  It cannot be
; .include'd because it varies based on the score's filename.

.import pently_init, pently_start_sound, pently_start_music, pently_update
.import __ROM7_START__, __ROM7_LAST__
.exportzp psg_sfx_state, tvSystem

.include "../../src/pentlyconfig.inc"

.segment "NSFEHEADER"
  .byt "NSFE"  ; signature

  ; INFO chunk: load, init, and run addresses
  .dword INFO_end-INFO_start
  .byt "INFO"
INFO_start:
  .addr __ROM7_START__  ; load address (should match link script)
  .addr init_sound_and_music
  .addr pently_update
  .if PENTLY_USE_PAL_ADJUST
    .byt $02  ; NTSC/PAL dual compatible; NTSC preferred
  .else
    .byt $00  ; NTSC only
  .endif
  .byt $00 ; no Famicom expansion sound

  .if PENTLY_USE_NSF_SOUND_FX
    .byt NUM_SONGS+NUM_SOUNDS
  .else
    .byt NUM_SONGS
  .endif
  .byt 0  ; first song to play
INFO_end:

  ; auth chunk contains up to four UTF8-encoded, NUL-terminated
  ; strings in this order: title, artist, year and publisher, ripper
  .dword auth_end-auth_start
  .byt "auth"
auth_start:
  PENTLY_WRITE_NSFE_TITLE
  .byt $00
  PENTLY_WRITE_NSFE_AUTHOR
  .byt $00
  PENTLY_WRITE_NSFE_COPYRIGHT
  .byt $00
auth_end:

  ; tlbl, taut: NUL-terminated song titles and authors
  .dword tlbl_end-tlbl_start
  .byt "tlbl"
tlbl_start:
  PENTLY_WRITE_SONG_TITLES $00
tlbl_end:

  .dword taut_end-taut_start
  .byt "taut"
taut_start:
  PENTLY_WRITE_SONG_AUTHORS $00
taut_end:

  ; time: 4-byte durations in milliseconds of end of song (if not
  ; looping) or end of second loop
  .dword time_end-time_start
  .byt "time"
time_start:
  PENTLY_WRITE_NSFE_DURATIONS
time_end:

  ; fade: 4-byte durations in milliseconds of fade after end of song.
  ; Convention is -1 (player-specified fade duration) for looping
  ; tracks or 0 (no fade) for tracks that end
  .dword fade_end-fade_start
  .byt "fade"
fade_start:
  PENTLY_WRITE_NSFE_FADES
fade_end:

  ; Mark sound effects as such so that a player can construct "all
  ; songs" and "all sound effects" playlists
  ; TODO once pentlyas gains nsfshelldata output, as the length of
  ; this chunk depends on the score, which is currently .import'd
  ; as opposed to being a constant
  .if PENTLY_USE_NSF_SOUND_FX
    .dword NUM_SOUNDS
    .byt "psfx"
    .repeat NUM_SOUNDS, I
      .byte NUM_SONGS + I
    .endrepeat
  .endif

  ; Show off Dendy compatibility if enabled
  .if PENTLY_USE_PAL_ADJUST
    .dword 2
    .byt "regn"
    .byt $07, $00
  .endif

  ; this chunk MUST occur after INFO, but due to the structure of the
  ; link script, it must occur last in the NSFEHEADER
  .dword __ROM7_LAST__-__ROM7_START__
  .byt "DATA"

.segment "NSFEFOOTER"
  .dword 0
  .byt "NEND"

; All the actual code matches the NSF shell

.segment "ZEROPAGE"
psg_sfx_state: .res 36
tvSystem: .res 1

.segment "CODE"
.proc init_sound_and_music
   stx tvSystem
  pha
  jsr pently_init
  pla
  .if ::PENTLY_USE_NSF_SOUND_FX
    cmp #NUM_SONGS
    bcc is_music
      sbc #NUM_SONGS
      jmp pently_start_sound
    is_music:
  .endif
  jmp pently_start_music
.endproc

