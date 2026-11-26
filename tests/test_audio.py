"""Exercise the real 16-bit audio code and game events in Unicorn.

Run from the project root after installing NASM and the Python ``unicorn``
package: ``python tests/test_audio.py``. Set NASM to override the executable.
All test builds are made in a temporary directory; MARIO.COM is not changed.
"""

import os
import struct
import subprocess
import tempfile
from pathlib import Path

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INSN, UcError
from unicorn.x86_const import (
    UC_X86_INS_IN,
    UC_X86_INS_OUT,
    UC_X86_REG_AX,
    UC_X86_REG_BX,
    UC_X86_REG_CX,
    UC_X86_REG_DX,
    UC_X86_REG_SI,
    UC_X86_REG_DI,
    UC_X86_REG_BP,
    UC_X86_REG_SP,
    UC_X86_REG_IP,
    UC_X86_REG_CS,
    UC_X86_REG_DS,
    UC_X86_REG_ES,
    UC_X86_REG_SS,
    UC_X86_REG_EFLAGS,
)

ROOT = Path(__file__).resolve().parents[1]
NAMES = """sound_muted sound_m_held sound_fx_ptr sound_fx_ticks sound_fx_priority
sound_music_ptr sound_music_ticks sound_music sound_update sound_stop sound_jump
sound_coin sound_stomp sound_power sound_life sound_hurt sound_death sound_win
sound_jump_notes sound_coin_notes sound_stomp_notes sound_power_notes
sound_life_notes sound_hurt_notes sound_death_notes sound_win_notes game_state
key_state resetlevel addcoin coins lives score_lo mario_x mario_y mario_vy
mario_prev_y on_ground mario_form mario_hp invuln_timer pit_death movemario
hurtmario start_death updatemush mush_active mush_x mush_y mush_dir check_items
updateenemies enemies work_map state_timer""".split()


def build_test_image():
    """Append a symbol table to a temporary, otherwise identical COM build."""
    nasm = os.environ.get("NASM", "nasm")
    with tempfile.TemporaryDirectory(prefix="mario-audio-test-") as directory:
        directory = Path(directory)
        plain = directory / "mario.com"
        wrapper = directory / "testable.asm"
        instrumented = directory / "testable.com"
        wrapper.write_text(
            '%include "src/mario.asm"\n'
            + "".join("dw " + name + "\n" for name in NAMES)
        )
        subprocess.run(
            [nasm, "-f", "bin", "src/mario.asm", "-o", str(plain)], cwd=ROOT, check=True
        )
        subprocess.run(
            [nasm, "-f", "bin", str(wrapper), "-o", str(instrumented)],
            cwd=ROOT,
            check=True,
        )
        original = plain.read_bytes()
        extended = instrumented.read_bytes()
        assert (
            extended[: len(original)] == original
        ), "Instrumented build differs from the game"
        symbols = dict(
            zip(NAMES, struct.unpack("<" + "H" * len(NAMES), extended[len(original) :]))
        )
        return original, symbols


orig, sym = build_test_image()
SEG = 0x1000
BASE = SEG << 4
SENTINEL = 0xFFFE


class Game:
    def __init__(self):
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x200000)
        self.uc.mem_write(BASE + 0x100, orig)
        for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
            self.uc.reg_write(r, SEG)
        self.uc.reg_write(UC_X86_REG_EFLAGS, 0x202)
        self.port61 = 0xA8
        self.out = []
        self.uc.hook_add(UC_HOOK_INSN, self.io_in, None, 1, 0, UC_X86_INS_IN)
        self.uc.hook_add(UC_HOOK_INSN, self.io_out, None, 1, 0, UC_X86_INS_OUT)

    def io_in(self, uc, port, size, data):
        return self.port61 if port == 0x61 else 0

    def io_out(self, uc, port, size, value, data):
        self.out.append((port, size, value))
        if port == 0x61:
            self.port61 = value

    def call(self, name):
        self.uc.reg_write(UC_X86_REG_SP, 0xF000)
        self.uc.mem_write(BASE + 0xF000, struct.pack("<H", SENTINEL))
        try:
            self.uc.emu_start(BASE + sym[name], BASE + SENTINEL, count=1500000)
        except UcError as e:
            raise AssertionError(
                f"{name}: {e}, ip={self.uc.reg_read(UC_X86_REG_IP):x}"
            ) from e
        assert self.uc.reg_read(UC_X86_REG_IP) == SENTINEL, f"{name} did not return"
        assert self.uc.reg_read(UC_X86_REG_SP) == 0xF002, f"{name} damaged the stack"

    def b(self, name):
        return self.uc.mem_read(BASE + sym[name], 1)[0]

    def w(self, name):
        return struct.unpack("<H", self.uc.mem_read(BASE + sym[name], 2))[0]

    def setb(self, name, value):
        self.uc.mem_write(BASE + sym[name], bytes([value & 0xFF]))

    def setw(self, name, value):
        self.uc.mem_write(BASE + sym[name], struct.pack("<H", value & 0xFFFF))

    def key(self, scancode, value):
        self.uc.mem_write(BASE + sym["key_state"] + scancode, bytes([value]))

    def set_enemy(self, index, type, state, x, y, direction=0, timer=0):
        self.uc.mem_write(
            BASE + sym["enemies"] + index * 16,
            struct.pack("<BBHHBB", type, state, x, y, direction, timer) + bytes(8),
        )

    def enemy_state(self, index):
        return self.uc.mem_read(BASE + sym["enemies"] + index * 16 + 1, 1)[0]

    def divisor_writes(self):
        vals = [v for p, s, v in self.out if p == 0x42]
        assert len(vals) % 2 == 0
        return [a | (b << 8) for a, b in zip(vals[::2], vals[1::2])]


def check(name, fn):
    fn()
    print("PASS", name)


def test_notes_and_timing():
    g = Game()
    g.setb("game_state", 0)
    g.call("sound_update")
    assert g.port61 == 0xA8
    g.setb("game_state", 1)
    g.out = []
    g.call("sound_update")
    assert g.port61 == 0xAB
    assert g.divisor_writes() == [2281]
    assert (0x43, 1, 0xB6) in g.out
    assert g.b("sound_music_ticks") == 3
    g.call("sound_update")
    g.call("sound_update")
    assert g.divisor_writes() == [2281]
    g.call("sound_update")
    assert g.divisor_writes() == [2281, 1810]
    assert all(p in (0x42, 0x43, 0x61) for p, _, _ in g.out)


def test_mute_pause_exit():
    g = Game()
    g.setb("game_state", 1)
    g.call("sound_update")
    assert g.port61 & 3 == 3
    g.key(0x32, 1)
    g.call("sound_update")
    assert g.b("sound_muted") == 1 and g.port61 & 3 == 0
    for _ in range(15):
        g.call("sound_update")
    assert g.b("sound_muted") == 1
    g.call("sound_coin")
    assert g.w("sound_fx_ptr") == 0
    g.key(0x32, 0)
    g.call("sound_update")
    g.key(0x32, 1)
    g.call("sound_update")
    assert g.b("sound_muted") == 0 and g.port61 & 3 == 3
    g.setb("game_state", 2)
    g.call("sound_update")
    assert g.port61 == 0xA8
    g.setb("game_state", 1)
    g.call("sound_update")
    assert g.port61 == 0xAB
    g.setb("game_state", 0)
    g.call("sound_update")
    assert g.port61 == 0xA8 and g.w("sound_music_ptr") == sym["sound_music"]
    g.setb("game_state", 1)
    g.call("sound_update")
    g.call("sound_stop")
    assert g.port61 == 0xA8


def test_priority_and_preservation():
    g = Game()
    g.setb("game_state", 1)
    # Event entry points must not disturb callers' registers, flags or stack.
    for reg, v in [
        (UC_X86_REG_AX, 0x789A),
        (UC_X86_REG_BX, 0x1234),
        (UC_X86_REG_CX, 0x3456),
        (UC_X86_REG_DX, 0x5678),
        (UC_X86_REG_SI, 0x9ABC),
        (UC_X86_REG_DI, 0xDEF0),
        (UC_X86_REG_BP, 0x1357),
    ]:
        g.uc.reg_write(reg, v)
    g.uc.reg_write(UC_X86_REG_EFLAGS, 0x8D3)
    before = [
        g.uc.reg_read(r)
        for r in [
            UC_X86_REG_AX,
            UC_X86_REG_BX,
            UC_X86_REG_CX,
            UC_X86_REG_DX,
            UC_X86_REG_SI,
            UC_X86_REG_DI,
            UC_X86_REG_BP,
            UC_X86_REG_EFLAGS,
        ]
    ]
    g.call("sound_jump")
    after = [
        g.uc.reg_read(r)
        for r in [
            UC_X86_REG_AX,
            UC_X86_REG_BX,
            UC_X86_REG_CX,
            UC_X86_REG_DX,
            UC_X86_REG_SI,
            UC_X86_REG_DI,
            UC_X86_REG_BP,
            UC_X86_REG_EFLAGS,
        ]
    ]
    assert before == after, (before, after)
    assert (
        g.w("sound_fx_ptr") == sym["sound_jump_notes"] and g.b("sound_fx_priority") == 1
    )
    g.call("sound_life")
    assert (
        g.w("sound_fx_ptr") == sym["sound_life_notes"] and g.b("sound_fx_priority") == 3
    )
    g.call("sound_coin")
    assert g.w("sound_fx_ptr") == sym["sound_life_notes"]
    g.call("sound_death")
    assert (
        g.w("sound_fx_ptr") == sym["sound_death_notes"]
        and g.b("sound_fx_priority") == 4
    )
    g.call("sound_power")
    assert g.w("sound_fx_ptr") == sym["sound_death_notes"]
    g.out = []
    g.call("sound_update")
    assert g.divisor_writes() == [1522]
    for _ in range(15):
        g.call("sound_update")
    assert g.w("sound_fx_ptr") == 0 and g.b("sound_fx_priority") == 0
    assert g.divisor_writes()[:4] == [1522, 1810, 2281, 3044]
    assert g.divisor_writes()[-1] == 2281  # music resumes immediately after effect


def test_jump():
    g = Game()
    g.call("resetlevel")
    g.setb("game_state", 1)
    g.key(0x39, 1)
    g.call("movemario")
    assert g.w("sound_fx_ptr") == sym["sound_jump_notes"]
    assert g.b("on_ground") == 0 and g.w("mario_vy") > 0x8000


def test_coin_and_life():
    g = Game()
    g.setb("game_state", 1)
    g.setb("coins", 0)
    g.setb("lives", 3)
    g.call("addcoin")
    assert (g.b("coins"), g.b("lives"), g.w("score_lo")) == (1, 3, 200)
    assert g.w("sound_fx_ptr") == sym["sound_coin_notes"]
    g.setb("coins", 99)
    g.call("addcoin")
    assert (g.b("coins"), g.b("lives"), g.w("score_lo")) == (0, 4, 400)
    assert g.w("sound_fx_ptr") == sym["sound_life_notes"]


def test_mushroom():
    g = Game()
    g.call("resetlevel")
    g.setb("game_state", 1)
    g.setb("mush_active", 1)
    g.setw("mush_x", 32)
    g.setw("mush_y", 144)
    g.setb("mush_dir", 1)
    g.call("updatemush")
    assert (g.b("mush_active"), g.b("mario_hp"), g.b("mario_form")) == (0, 2, 1)
    assert g.w("sound_fx_ptr") == sym["sound_power_notes"]


def test_hurt_and_death():
    g = Game()
    g.call("resetlevel")
    g.setb("game_state", 1)
    g.setb("mario_hp", 2)
    g.setb("mario_form", 1)
    g.call("hurtmario")
    assert (g.b("mario_hp"), g.b("mario_form"), g.b("invuln_timer")) == (1, 0, 36)
    assert g.w("sound_fx_ptr") == sym["sound_hurt_notes"]
    g.setb("invuln_timer", 0)
    g.call("hurtmario")
    assert g.b("game_state") == 3
    assert g.w("sound_fx_ptr") == sym["sound_death_notes"]
    g.out = []
    g.call("sound_update")
    assert g.divisor_writes() == [1522]


def test_stomp_and_kick():
    g = Game()
    g.call("resetlevel")
    g.setb("game_state", 1)
    g.set_enemy(0, 1, 2, 100, 144)
    g.setw("mario_x", 99)
    g.setw("mario_y", 130)
    g.setw("mario_prev_y", 126)
    g.setw("mario_vy", 0x0100)
    g.call("updateenemies")
    assert g.enemy_state(0) == 3 and g.w("sound_fx_ptr") == sym["sound_stomp_notes"]
    g = Game()
    g.call("resetlevel")
    g.setb("game_state", 1)
    g.set_enemy(0, 2, 4, 100, 144)
    g.setw("mario_x", 99)
    g.setw("mario_y", 144)
    g.call("updateenemies")
    assert g.enemy_state(0) == 5 and g.w("sound_fx_ptr") == sym["sound_stomp_notes"]


def test_flag_win():
    g = Game()
    g.call("resetlevel")
    g.setb("game_state", 1)
    g.setw("mario_x", 896)
    g.setw("mario_y", 128)
    g.call("check_items")
    assert g.b("game_state") == 5 and g.w("state_timer") == 55
    assert g.w("sound_fx_ptr") == sym["sound_win_notes"]
    g.out = []
    g.call("sound_update")
    assert g.divisor_writes() == [2281]


if __name__ == "__main__":
    for name, fn in [
        ("speaker and note timing", test_notes_and_timing),
        ("mute, hold, pause, resume, title, exit", test_mute_pause_exit),
        ("priority and register preservation", test_priority_and_preservation),
        ("jump effect", test_jump),
        ("coin and extra-life effects", test_coin_and_life),
        ("mushroom effect", test_mushroom),
        ("damage and death effects", test_hurt_and_death),
        ("enemy stomp and shell kick effects", test_stomp_and_kick),
        ("flagpole victory effect", test_flag_win),
    ]:
        check(name, fn)
    print("All audio-focused tests passed.")
