# RISC-V M Extension (RV32IM)

Starter repo for your single-cycle RV32I core extended with the M extension (multiply and divide) (Groups 1 to 4). One member creates the group's repo with **Use this template** → **Create a new repository** (public), and adds the others as collaborators.

Copy your single-cycle core into this repo and add the M instructions; the ports are the same as your single-cycle core's.

Spec: [Single_Cycle_RISCV_M/](Single_Cycle_RISCV_M/)

## Submit

1. Install the **`risc-n-roll-ci`** GitHub App on your group's repo (that exact repo, or CI never sees it).
2. Write your design, commit and push. `rnr-stage.yaml` suggests `Single_Cycle_RISCV_M/rtl.sv`; if you use other file names, edit the paths there (no spaces in paths).
3. Submit your repo link (one per group) through the course form.

CI checks each push on its next run, which can take a few hours. Its synthesizer (Yosys 0.33) cannot parse assignment patterns like `'{default: 0}`; use a `for` loop instead.

## Implementation

`single_cycle_riscv_m` ([Single_Cycle_RISCV_M/single_cycle_riscv_m.sv](Single_Cycle_RISCV_M/single_cycle_riscv_m.sv)) is the single-cycle RV32I core (IF / ID / EX / WB stages) plus a combinational M unit, [`muldiv.sv`](Single_Cycle_RISCV_M/muldiv.sv). For R-type instructions with `funct7 = 0000001` the top level writes back the `muldiv` result instead of the normal WB data. Every M instruction finishes in one cycle, and all files are listed in `rnr-stage.yaml`.

## Verification

**Compliance:** the official [riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test) release `2.7.4` (ships golden reference signatures) passes **46/46** (`rv32i_m/I` 38/38, `rv32i_m/M` 8/8):

```sh
git clone -b 2.7.4 https://github.com/riscv-non-isa/riscv-arch-test.git
RISCV_PREFIX=riscv64-unknown-elf- python3 compliance/run_compliance.py riscv-arch-test   # suites I M
```

Needs Verilator 5 and a RISC-V GCC (`gcc-riscv64-unknown-elf` on Ubuntu). `compliance/tb_arch.sv` gives the core one unified memory at `0x80000000`, stops when the test writes `tohost`, and dumps `begin_signature..end_signature` for comparison.

**Random differential test:** `tb/run.py` checks the RTL against a Python RV32IM model on directed and random programs (corner operands such as 0, -1, `0x80000000`, divide by zero, signed overflow; plus stalls and resets):

```sh
cd tb
verilator --binary --timing -Wno-fatal --top-module tb -Mdir obj -o Vtb tb.sv $(ls ../*/*.sv | grep -v '/tb/\|compliance')
python3 run.py <seed> <count>
```
