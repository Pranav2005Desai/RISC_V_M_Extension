#!/usr/bin/env python3
"""Run riscv-arch-test (v2.7.4, which ships golden reference signatures) on the RTL.

usage: run_compliance.py <path-to-riscv-arch-test@2.7.4> [suite ...]   (default suites: I M)
env:   RISCV_PREFIX  toolchain prefix (default riscv64-unknown-elf-)
"""
import os, re, subprocess, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PREFIX = os.environ.get("RISCV_PREFIX", "riscv64-unknown-elf-")
WORK = os.path.join(HERE, "work")


def sh(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        sys.exit(f"command failed: {' '.join(cmd)}\n{r.stderr}")
    return r.stdout


def build_sim():
    rtl = sorted(glob.glob(os.path.join(ROOT, "*", "*.sv")))
    rtl = [f for f in rtl if os.sep + "tb" + os.sep not in f and "compliance" not in f]
    sh(["verilator", "--binary", "--timing", "-Wno-fatal", "-O3", "--top-module", "tb_arch",
        "-Mdir", os.path.join(WORK, "obj"), "-j", str(os.cpu_count()), "-o", "Vtb_arch",
        os.path.join(HERE, "tb_arch.sv"), *rtl])
    return os.path.join(WORK, "obj", "Vtb_arch")


def run_test(sim, src, ref, out, env):
    name = os.path.basename(src)[:-2]
    pre, elf, hexf, sig = (os.path.join(out, name + e) for e in (".s", ".elf", ".hex", ".signature.output"))
    sh([PREFIX + "gcc", "-E", "-DXLEN=32", "-DTEST_CASE_1=True", "-I", env, "-I", HERE, src, "-o", pre])
    # Newer binutils reject `la x0, sym` (used by jalr-01 for rd=x0). With rd=x0 it is
    # architecturally a no-op pair, so emit the same two instructions explicitly.
    asm = re.sub(r"\bla\s+x0\s*,[^;\n]*", "auipc x0, 0; addi x0, x0, 0", open(pre).read())
    open(pre, "w").write(asm)
    sh([PREFIX + "gcc", "-march=rv32im", "-mabi=ilp32", "-static", "-mcmodel=medany",
        "-fvisibility=hidden", "-nostdlib", "-nostartfiles",
        "-T", os.path.join(HERE, "link.ld"), pre, "-o", elf])
    sh([PREFIX + "objcopy", "-O", "verilog", "--change-addresses", "-0x80000000", elf, hexf])
    open(elf + ".objdump", "w").write(sh([PREFIX + "objdump", "-D", elf]))
    syms = {l.split()[2]: l.split()[0] for l in sh([PREFIX + "nm", elf]).splitlines() if len(l.split()) == 3}
    log = sh([sim, f"+HEX={hexf}", f"+SIG={sig}", f"+BEGIN={syms['begin_signature']}",
              f"+END={syms['end_signature']}", f"+TOHOST={syms['tohost']}"])
    got = open(sig).read().split()
    exp = open(ref).read().split()
    halted = "HALT" in log
    ok = halted and got == exp
    detail = log.strip().splitlines()[0] if log.strip() else ""
    if halted and got != exp:
        bad = [i for i, (g, e) in enumerate(zip(got, exp)) if g != e]
        detail += f"; {len(bad)} word(s) differ" if bad else f"; length {len(got)} vs {len(exp)}"
        if bad: detail += f", first @+{4*bad[0]:#x}: got {got[bad[0]]} exp {exp[bad[0]]}"
    return name, ok, detail, len(exp)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    at = os.path.abspath(sys.argv[1])
    suites = sys.argv[2:] or ["I", "M"]
    os.makedirs(WORK, exist_ok=True)
    sim = build_sim()
    total = fails = 0
    for s in suites:
        d = os.path.join(at, "riscv-test-suite", "rv32i_m", s)
        out = os.path.join(WORK, s); os.makedirs(out, exist_ok=True)
        print(f"== rv32i_m/{s}")
        for src in sorted(glob.glob(os.path.join(d, "src", "*.S"))):
            ref = os.path.join(d, "references", os.path.basename(src)[:-2] + ".reference_output")
            name, ok, detail, n = run_test(sim, src, ref, out, os.path.join(at, "riscv-test-suite", "env"))
            total += 1; fails += not ok
            print(f"  {'PASS' if ok else 'FAIL'}  {name:<16} ({n} sig words)  {detail if not ok else ''}")
    print(f"\n{total - fails}/{total} tests passed")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
