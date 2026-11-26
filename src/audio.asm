; Non-blocking, monophonic PC speaker music and effects.
; PIT channel 2 uses a 1,193,182 Hz clock. Each note is a 16-bit divisor
; followed by a duration in game frames (about 18 frames per second).
; A zero divisor is a rest; a zero duration marks the end of a sequence.

sound_muted:       db 0
sound_m_held:      db 0
sound_fx_ptr:      dw 0
sound_fx_ticks:    db 0
sound_fx_priority: db 0
sound_music_ptr:   dw sound_music
sound_music_ticks: db 0

; Original, short background loop. Effects temporarily take priority.
sound_music:
    dw 2281                 ; C5
    db 3
    dw 1810                 ; E5
    db 3
    dw 1522                 ; G5
    db 3
    dw 1810                 ; E5
    db 3
    dw 1356                 ; A5
    db 3
    dw 1522                 ; G5
    db 4
    dw 0                    ; rest
    db 1
    dw 1810                 ; E5
    db 3
    dw 2033                 ; D5
    db 3
    dw 1709                 ; F5
    db 3
    dw 1356                 ; A5
    db 3
    dw 1522                 ; G5
    db 3
    dw 1810                 ; E5
    db 3
    dw 2281                 ; C5
    db 4
    dw 0
    db 1
    dw 1810                 ; E5
    db 3
    dw 1522                 ; G5
    db 3
    dw 1139                 ; C6
    db 4
    dw 1208                 ; B5
    db 2
    dw 1522                 ; G5
    db 4
    dw 1709                 ; F5
    db 3
    dw 1356                 ; A5
    db 3
    dw 1016                 ; D6
    db 4
    dw 1139                 ; C6
    db 2
    dw 1356                 ; A5
    db 4
    dw 1522                 ; G5
    db 3
    dw 1810                 ; E5
    db 3
    dw 2033                 ; D5
    db 3
    dw 2281                 ; C5
    db 6
    dw 0
    db 2
    dw 0
    db 0

; Effect sequences are short so the music returns promptly.
%macro SOUND_NOTE 2
    dw %1
    db %2
%endmacro

sound_jump_notes:
    SOUND_NOTE 1522, 2         ; G5, B5
    SOUND_NOTE 1208, 2
    SOUND_NOTE 0, 0
sound_coin_notes:
    SOUND_NOTE 1208, 1         ; B5, E6
    SOUND_NOTE 905, 2
    SOUND_NOTE 0, 0
sound_stomp_notes:
    SOUND_NOTE 3619, 2         ; E4, G4
    SOUND_NOTE 3044, 2
    SOUND_NOTE 0, 0
sound_power_notes:
    SOUND_NOTE 2281, 2         ; C5, E5, G5, C6
    SOUND_NOTE 1810, 2
    SOUND_NOTE 1522, 2
    SOUND_NOTE 1139, 3
    SOUND_NOTE 0, 0
sound_life_notes:
    SOUND_NOTE 1810, 2         ; E5, G5, C6, E6
    SOUND_NOTE 1522, 2
    SOUND_NOTE 1139, 2
    SOUND_NOTE 905, 4
    SOUND_NOTE 0, 0
sound_hurt_notes:
    SOUND_NOTE 1810, 3         ; E5, C5
    SOUND_NOTE 2281, 3
    SOUND_NOTE 0, 0
sound_death_notes:
    SOUND_NOTE 1522, 3         ; G5, E5, C5, G4
    SOUND_NOTE 1810, 3
    SOUND_NOTE 2281, 3
    SOUND_NOTE 3044, 6
    SOUND_NOTE 0, 0
sound_win_notes:
    SOUND_NOTE 2281, 2         ; C5, E5, G5, C6, E6, C6
    SOUND_NOTE 1810, 2
    SOUND_NOTE 1522, 2
    SOUND_NOTE 1139, 6
    SOUND_NOTE 905, 4
    SOUND_NOTE 1139, 5
    SOUND_NOTE 0, 0

; Queue an effect. SI = note sequence, AL = priority (1 through 4).
; A higher-priority effect cannot be interrupted by a lower-priority one.
sound_queue:
    cmp byte [sound_muted], 0
    jne .done
    cmp al, [sound_fx_priority]
    jb .done
    mov [sound_fx_ptr], si
    mov [sound_fx_priority], al
    mov byte [sound_fx_ticks], 0
    ; Resume the music at its next note after the effect.
    mov byte [sound_music_ticks], 0
.done:
    ret

; Event entry points preserve registers and flags for the game logic.
%macro SOUND_EVENT 3
%1:
    pushf
    push ax
    push si
    mov si, %2
    mov al, %3
    call sound_queue
    pop si
    pop ax
    popf
    ret
%endmacro

SOUND_EVENT sound_jump,    sound_jump_notes,  1
SOUND_EVENT sound_coin,    sound_coin_notes,  2
SOUND_EVENT sound_stomp,   sound_stomp_notes, 2
SOUND_EVENT sound_power,   sound_power_notes, 3
SOUND_EVENT sound_life,    sound_life_notes,  3
SOUND_EVENT sound_hurt,    sound_hurt_notes,  3
SOUND_EVENT sound_death,   sound_death_notes, 4
SOUND_EVENT sound_win,     sound_win_notes,   4

; Program PIT channel 2 and enable the PC speaker. AX = divisor.
; A divisor of zero silences the speaker for a rest.
sound_note:
    test ax, ax
    jz sound_speaker_off
    push ax
    push bx
    mov bx, ax
    mov al, 0xb6               ; channel 2, lobyte/hibyte, square wave
    out 0x43, al
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    pop bx
    pop ax
    ret

sound_speaker_off:
    push ax
    in al, 0x61
    and al, 0xfc               ; preserve the other port 61h bits
    out 0x61, al
    pop ax
    ret

; Cancel pending effects and silence the speaker, e.g. on pause or exit.
sound_stop:
    mov word [sound_fx_ptr], 0
    mov byte [sound_fx_ticks], 0
    mov byte [sound_fx_priority], 0
    mov byte [sound_music_ticks], 0
    call sound_speaker_off
    ret

; Called once per game frame, after the state update. Never waits for sound.
; M is edge-triggered so holding it does not repeatedly toggle mute.
sound_update:
    push ax
    push bx
    push si

    cmp byte [key_state + KEY_M], 0
    jne .m_down
    mov byte [sound_m_held], 0
    jmp .m_done
.m_down:
    cmp byte [sound_m_held], 0
    jne .m_done
    mov byte [sound_m_held], 1
    xor byte [sound_muted], 1
.m_done:
    cmp byte [sound_muted], 0
    jne .quiet
    cmp byte [game_state], ST_TITLE
    je .title
    cmp byte [game_state], ST_PAUSE
    je .quiet
    cmp byte [game_state], ST_EXIT
    je .quiet

    ; Effects also play during the death and flagpole sequences.
    cmp word [sound_fx_ptr], 0
    jne .effect
    cmp byte [game_state], ST_PLAY
    jne .quiet

.music:
    cmp byte [sound_music_ticks], 0
    je .music_next
    dec byte [sound_music_ticks]
    jnz .done
.music_next:
    mov si, [sound_music_ptr]
    mov ax, [si]
    mov bl, [si + 2]
    or bl, bl
    jnz .music_note
    mov si, sound_music        ; loop back at the end marker
    mov ax, [si]
    mov bl, [si + 2]
.music_note:
    add si, 3
    mov [sound_music_ptr], si
    mov [sound_music_ticks], bl
    call sound_note
    jmp .done

.effect:
    cmp byte [sound_fx_ticks], 0
    je .effect_next
    dec byte [sound_fx_ticks]
    jnz .done
.effect_next:
    mov si, [sound_fx_ptr]
    mov ax, [si]
    mov bl, [si + 2]
    or bl, bl
    jz .effect_end
    add si, 3
    mov [sound_fx_ptr], si
    mov [sound_fx_ticks], bl
    call sound_note
    jmp .done
.effect_end:
    mov word [sound_fx_ptr], 0
    mov byte [sound_fx_priority], 0
    cmp byte [game_state], ST_PLAY
    je .music
    jmp .quiet

.title:
    mov word [sound_music_ptr], sound_music
.quiet:
    call sound_stop
.done:
    pop si
    pop bx
    pop ax
    ret
