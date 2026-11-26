; super mario engine - main file and data
; asmad nadeem (25F-0537), faisal shahzad (25F-0619), umar saleem (25F-0545)

[org 0x0100]

jmp start

; constants
SCREEN_W        equ 320
SCREEN_H        equ 200
MAP_COLS        equ 60
MAP_ROWS        equ 12
MAP_SIZE        equ 720
WORLD_W         equ 960
MAX_CAM         equ 640
MAX_ENEMIES     equ 8
ENEMY_SIZE      equ 16

; palette colors
COL_BLACK       equ 0
COL_BLUE        equ 1
COL_GREEN       equ 2
COL_RED         equ 4
COL_BROWN       equ 6
COL_DGREY       equ 8
COL_LGREEN      equ 10
COL_LRED        equ 12
COL_YELLOW      equ 14
COL_WHITE       equ 15
COL_ORANGE      equ 42
COL_SKY         equ 53
COL_SKIN        equ 62

; tile codes
TILE_SKY        equ 0
TILE_GROUND     equ 1
TILE_BRICK      equ 2
TILE_Q_COIN     equ 3
TILE_Q_MUSH     equ 4
TILE_EMPTY      equ 5
TILE_PIPE_TL    equ 6
TILE_PIPE_TR    equ 7
TILE_PIPE_BL    equ 8
TILE_PIPE_BR    equ 9
TILE_STAIR      equ 10
TILE_COIN       equ 11
TILE_FLAG       equ 12

; scan codes
KEY_ESC         equ 0x01
KEY_T           equ 0x14
KEY_P           equ 0x19
KEY_ENTER       equ 0x1c
KEY_LSHIFT      equ 0x2a
KEY_C           equ 0x2e
KEY_M           equ 0x32
KEY_SPACE       equ 0x39
KEY_UP          equ 0x48
KEY_LEFT        equ 0x4b
KEY_RIGHT       equ 0x4d
KEY_DOWN        equ 0x50

; states
ST_TITLE        equ 0
ST_PLAY         equ 1
ST_PAUSE        equ 2
ST_DIE          equ 3
ST_LIFELOST     equ 4
ST_WINSEQ       equ 5
ST_LVLCOMP      equ 6
ST_GAMEOVER     equ 7
ST_EXIT         equ 8

; 8.8 fixed point physics constants
WALK_ACCEL      equ 0x0020
FRICTION        equ 0x0010
MAX_WALK        equ 0x0180
MAX_RUN         equ 0x0280
GRAVITY         equ 0x0040
JUMP_START      equ 0xfa80
JUMP_CUTOFF     equ 0xfe00
MAX_FALL        equ 0x0400
STOMP_BOUNCE    equ 0xfd00

; system variables
buf_seg:        dw 0
oldkb:          dd 0
oldtimer:       dd 0
key_state:      times 128 db 0
e0_flag:        db 0
tickcount:      dw 0
last_tick:      dw 0
sec_ticks:      db 0
frame_num:      dw 0

; state and camera variables
game_state:     db 0
menu_sel:       db 0
state_timer:    dw 0
camera_x:       dw 0

; hud and score variables
score_lo:       dw 0
score_hi:       dw 0
time_bonus:     dw 0
coins:          db 0
lives:          db 3
game_time:      dw 300

; mario variables
mario_x:        dw 32
mario_xf:       db 0
mario_y:        dw 144
mario_yf:       db 0
mario_vx:       dw 0
mario_vy:       dw 0
mario_prev_y:   dw 144
on_ground:      db 1
mario_form:     db 0
mario_hp:       db 1
invuln_timer:   db 0
stomp_chain:    dw 0
mario_dir:      db 0
mario_pose:     db 0
pit_death:      db 0

; mushroom variables
mush_active:    db 0
mush_x:         dw 0
mush_y:         dw 0
mush_dir:       db 1

stomp_table:    dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000

state_table:
    dw state_title
    dw state_play
    dw state_pause
    dw state_die
    dw state_lifelost
    dw state_winseq
    dw state_lvlcomp
    dw state_gameover

; text strings
str_title1:     db 'SUPER MARIO', 0
str_title2:     db 'E N G I N E', 0
str_start:      db 'START GAME', 0
str_exit:       db 'EXIT', 0
str_arrow:      db '>', 0
str_group:      db '25F-0537  25F-0619  25F-0545', 0
str_hud:        db 'SCORE   COINS  WORLD  TIME  LIVES  HP', 0
str_world:      db '1-1', 0
str_paused:     db 'PAUSED', 0
str_resume:     db 'Press P to resume', 0
str_w11:        db 'WORLD 1-1', 0
str_livesleft:  db 'LIVES LEFT', 0
str_lvlcomp:    db 'LEVEL COMPLETE!', 0
str_lcoins:     db 'COINS', 0
str_ltleft:     db 'TIME LEFT', 0
str_ltbon:      db 'TIME BONUS', 0
str_lfinal:     db 'FINAL SCORE', 0
str_enter:      db 'Press ENTER to continue', 0
str_gameover:   db 'GAME OVER', 0
str_soundon:    db 'M: SOUND ON', 0
str_soundoff:   db 'M: SOUND OFF', 0

; enemy table: type(1=goomba,2=koopa), state(1=wait), x(dw), y(dw), dir(db), timer(db), pad(8)
orig_enemies:
    db 1, 1
    dw 220, 144
    db 0, 0, 0,0,0,0,0,0,0,0
    db 1, 1
    dw 248, 144
    db 0, 0, 0,0,0,0,0,0,0,0
    db 2, 1
    dw 400, 144
    db 0, 0, 0,0,0,0,0,0,0,0
    db 1, 1
    dw 440, 144
    db 0, 0, 0,0,0,0,0,0,0,0
    db 2, 1
    dw 580, 144
    db 0, 0, 0,0,0,0,0,0,0,0
    db 1, 1
    dw 620, 144
    db 0, 0, 0,0,0,0,0,0,0,0
    times 32 db 0

enemies:        times 128 db 0

; 60x12 level map
orig_map:
    times 60 db 0
    times 60 db 0
    times 56 db 0
    db 12, 0, 0, 0
    times 14 db 0
    db 4, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0, 11,11,11, 0,0,0,0,0,0,0,0
    times 10 db 0
    db 12, 0, 0, 0
    times 56 db 0
    db 12, 0, 0, 0
    times 21 db 0
    db 11, 11, 11, 11
    times 9 db 0
    db 2, 3, 2, 0,0,0,0,0, 11, 11, 11
    times 11 db 0
    db 12, 0, 0, 0
    times 53 db 0
    db 10, 0, 0, 12, 0, 0, 0
    db 0,0,0,0,0,0,0, 3, 0, 4, 0, 2,2,2, 0,0,0, 0,0,0,0,0,0,0,0,0,0,0, 6,7
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0, 2,3,2, 0,0,0,0, 10,10, 0,0, 12, 0,0,0
    times 18 db 0
    db 6, 7
    times 8 db 0
    db 8, 9
    times 21 db 0
    db 10, 10, 10, 0, 0, 12, 0, 0, 0
    db 0,0,0,0, 11,11, 0,0,0,0,0,0,0,0,0,0,0,0, 8,9
    times 8 db 0
    db 8, 9
    db 0, 0, 11, 11, 11
    times 15 db 0
    db 10, 10, 10, 10, 0, 0, 10, 0, 0, 0
    times 22 db 1
    db 0, 0
    times 19 db 1
    db 0, 0
    times 15 db 1
    times 22 db 1
    db 0, 0
    times 19 db 1
    db 0, 0
    times 15 db 1

work_map:       times 720 db 0

; 16x16 sprites
spr_mario_s:
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,0,0,0
    db 0,0,0,0,6,6,6,62,62,0,62,0,0,0,0,0
    db 0,0,0,6,62,6,62,62,62,6,62,62,62,0,0,0
    db 0,0,0,6,62,6,6,62,62,62,6,6,6,0,0,0
    db 0,0,0,0,6,62,62,62,62,6,6,6,0,0,0,0
    db 0,0,0,0,4,4,1,4,4,1,4,0,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,1,4,4,0,0,0,0
    db 0,0,4,4,4,4,1,1,1,1,4,4,4,0,0,0
    db 0,0,62,62,4,1,14,1,1,14,1,4,62,62,0,0
    db 0,0,62,62,62,1,1,1,1,1,1,62,62,62,0,0
    db 0,0,62,62,1,1,1,1,1,1,1,1,62,62,0,0
    db 0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0
    db 0,0,0,6,6,6,0,0,0,0,6,6,6,0,0,0
    db 0,0,6,6,6,6,0,0,0,0,6,6,6,6,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

spr_mario_r:
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,0,0,0
    db 0,0,0,0,6,6,6,62,62,0,62,0,0,0,0,0
    db 0,0,0,6,62,6,62,62,62,6,62,62,62,0,0,0
    db 0,0,0,6,62,6,6,62,62,62,6,6,6,0,0,0
    db 0,0,0,0,6,62,62,62,62,6,6,6,0,0,0,0
    db 0,0,62,62,4,4,1,4,4,1,4,4,0,0,0,0
    db 0,0,62,62,4,4,1,1,1,1,4,4,62,62,0,0
    db 0,0,0,0,4,1,14,1,1,14,1,4,62,62,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,6,6,1,1,1,0,0,1,1,1,6,6,0,0
    db 0,0,6,6,6,0,0,0,0,0,0,6,6,6,0,0
    times 48 db 0

spr_goomba:
    db 0,0,0,0,0,0,6,6,6,6,0,0,0,0,0,0
    db 0,0,0,0,0,6,6,6,6,6,6,0,0,0,0,0
    db 0,0,0,0,6,6,6,6,6,6,6,6,0,0,0,0
    db 0,0,0,6,6,6,6,6,6,6,6,6,6,0,0,0
    db 0,0,6,6,15,15,6,6,6,6,15,15,6,6,0,0
    db 0,0,6,6,15,0,6,6,6,6,0,15,6,6,0,0
    db 0,6,6,6,15,0,6,6,6,6,0,15,6,6,6,0
    db 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0
    db 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0
    db 0,0,6,6,6,6,6,6,6,6,6,6,6,6,0,0
    db 0,0,0,0,62,62,62,62,62,62,62,62,0,0,0,0
    db 0,0,0,62,62,62,62,62,62,62,62,62,62,0,0,0
    db 0,0,0,62,62,62,62,62,62,62,62,62,62,0,0,0
    db 0,0,0,8,8,8,0,0,0,0,8,8,8,0,0,0
    db 0,0,8,8,8,8,0,0,0,0,8,8,8,8,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

spr_goomba_f:
    times 160 db 0
    db 0,0,0,6,6,6,6,6,6,6,6,6,6,0,0,0
    db 0,0,6,15,0,6,6,6,6,6,6,0,15,6,0,0
    db 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0
    db 0,0,0,62,62,62,62,62,62,62,62,62,62,0,0,0
    db 0,0,8,8,8,8,0,0,0,0,8,8,8,8,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

spr_koopa:
    db 0,0,0,0,14,14,14,0,0,0,0,0,0,0,0,0
    db 0,0,0,14,14,15,0,14,0,0,0,0,0,0,0,0
    db 0,0,0,14,14,15,0,14,0,0,0,0,0,0,0,0
    db 0,0,0,0,14,14,14,0,2,2,2,2,0,0,0,0
    db 0,0,0,0,0,14,0,2,2,10,10,2,2,0,0,0
    db 0,0,0,0,14,14,2,2,10,2,2,10,2,2,0,0
    db 0,0,0,0,14,2,2,10,2,2,2,2,10,2,0,0
    db 0,0,0,0,0,2,2,2,10,10,10,10,2,2,0,0
    db 0,0,0,0,0,2,2,2,2,2,2,2,2,2,0,0
    db 0,0,0,0,0,0,15,15,15,15,15,15,0,0,0,0
    db 0,0,0,0,0,14,14,14,0,0,14,14,14,0,0,0
    db 0,0,0,0,14,14,14,0,0,0,0,14,14,14,0,0
    times 64 db 0

spr_shell:
    times 64 db 0
    db 0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0
    db 0,0,0,0,2,2,10,10,10,10,2,2,0,0,0,0
    db 0,0,0,2,2,10,2,2,2,2,10,2,2,0,0,0
    db 0,0,2,2,10,2,2,10,10,2,2,10,2,2,0,0
    db 0,0,2,2,2,10,10,2,2,10,10,2,2,2,0,0
    db 0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0
    db 0,0,0,15,15,15,15,15,15,15,15,15,15,0,0,0
    db 0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,0
    times 64 db 0

spr_mush:
    db 0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0
    db 0,0,0,4,4,15,15,4,4,15,15,4,4,0,0,0
    db 0,0,4,4,15,15,15,4,4,15,15,15,4,4,0,0
    db 0,4,4,4,15,15,4,4,4,4,15,15,4,4,4,0
    db 0,4,4,4,4,4,4,15,15,4,4,4,4,4,4,0
    db 0,4,15,15,4,4,15,15,15,15,4,4,15,15,4,0
    db 0,4,15,15,4,4,15,15,15,15,4,4,15,15,4,0
    db 0,0,4,4,4,4,4,4,4,4,4,4,4,4,0,0
    db 0,0,0,0,62,62,62,62,62,62,62,62,0,0,0,0
    db 0,0,0,62,62,0,62,62,62,62,0,62,62,0,0,0
    db 0,0,0,62,62,0,62,62,62,62,0,62,62,0,0,0
    db 0,0,0,62,62,62,62,62,62,62,62,62,62,0,0,0
    db 0,0,0,0,62,62,62,62,62,62,62,62,0,0,0,0
    times 48 db 0

spr_heart1:
    db 0,12,12,0,0,12,12,0, 0,0,0,0,0,0,0,0
    db 12,12,12,12,12,12,12,12, 0,0,0,0,0,0,0,0
    db 12,12,12,12,12,12,12,12, 0,0,0,0,0,0,0,0
    db 0,12,12,12,12,12,12,0, 0,0,0,0,0,0,0,0
    db 0,0,12,12,12,12,0,0, 0,0,0,0,0,0,0,0
    db 0,0,0,12,12,0,0,0, 0,0,0,0,0,0,0,0
    times 160 db 0

spr_heart0:
    db 0,8,8,0,0,8,8,0, 0,0,0,0,0,0,0,0
    db 8,0,0,8,8,0,0,8, 0,0,0,0,0,0,0,0
    db 8,0,0,0,0,0,0,8, 0,0,0,0,0,0,0,0
    db 0,8,0,0,0,0,8,0, 0,0,0,0,0,0,0,0
    db 0,0,8,0,0,8,0,0, 0,0,0,0,0,0,0,0
    db 0,0,0,8,8,0,0,0, 0,0,0,0,0,0,0,0
    times 160 db 0

start:
    cld
    mov ax, cs
    add ax, 0x1000
    mov [buf_seg], ax

    mov ax, 0x0013
    int 0x10

    call hook_ints
    call newgame

mainloop:
    cmp byte [game_state], ST_EXIT
    je exit_prog

    call waitframe

    xor bx, bx
    mov bl, [game_state]
    shl bx, 1
    call [state_table + bx]
    call sound_update

    call copybuf
    inc word [frame_num]
    jmp mainloop

exit_prog:
    call sound_stop
    call unhook_ints
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21

%include "src/gfx.asm"
%include "src/phys.asm"
%include "src/game.asm"
%include "src/audio.asm"
