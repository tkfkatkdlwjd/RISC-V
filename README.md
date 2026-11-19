# Single-Cycle RV32I

A 32-bit RISC-V single-cycle core written in SystemVerilog.

## Structure

![Single-cycle datapath](docs/datapath.svg)

- Instructions and data share a single 16KB memory. Reads are asynchronous; writes are synchronous to the clock.
- The next PC is `PC + 4` by default, `PC + imm` for a taken branch or `jal`, and `(rs1 + imm) & ~1` for `jalr`.
- The branch condition is bit 0 of the ALU compare result.
- The write-back mux selects the ALU result, memory data, `PC + 4`, or the immediate using `Mresult`. Sign extension for byte/halfword loads is done here.

## Features

- 32-bit RISC-V single-cycle CPU core.
- Supports RV32I except `fence` and `ebreak`. No multiplication/division, no CSR unit.
- Instruction fetch, memory access, and register write-back all complete in one cycle.
- No cache; 16KB memory unit.
- Instruction fetch and data access share the same memory unit.
- Clock period is 25.0 ns (40 MHz). The critical path is the load path, which reads memory twice in one cycle: once for the instruction and once for the data.
- The `ecall` instruction is used only to end the simulation.

## Versions

### v1.0.1

- Add README.
- Fix latches on `d_data` in `mem_16k`.
- Add `test` output to `top` for synthesis.
- Add Vivado synthesis reports.
- Move design files to `src/` and testbenches to `sim/`.

## Directory structure

| Folder | Contents |
|---|---|
| [`src/`](src) | SystemVerilog design files and the clock constraint (`constraints.xdc`) |
| [`sim/`](sim) | Testbenches: the CPU testbench (`tb_top.sv`) and unit testbenches |
| [`programs/`](programs) | `rv32ui` test programs (hex), a sample program, and linker scripts |
| [`synthesis/`](synthesis) | Vivado utilization, timing, power, and DRC reports |
| [`docs/`](docs) | Datapath diagram |

## Modules

File paths below are relative to [`src/`](src).

| File | Module | Description |
|---|---|---|
| `top.sv` | `top` | Connects the core and memory |
| `single-cycle.sv` | `single_cycle_core` | Datapath, next-PC logic, write-back mux |
| `instr_decoder.sv` | `instr_decoder` | Decodes opcode, funct3, and funct7 into control signals |
| `imm_maker.sv` | `imm_maker` | Builds I/S/B/U/J-type immediates; detects `ecall`/`ebreak` |
| `function_unit.sv` | `funct_unit` | Arithmetic, logic, shift, and compare operations |
| `register_file.sv` | `reg_file` | 32 x 32-bit registers (`x0` = 0) |
| `program_counter.sv` | `PC` | PC register |
| `memory.sv` | `mem_16k` | 16KB instruction/data memory |
| `pkg_rv32i.sv` | `rv32i` | Opcodes, operation codes, mux select constants |

## Module details

### Hierarchy

```
top
├── single_cycle_core (core)
│   ├── PC             (program_counter)
│   ├── instr_decoder  (main_decoder)
│   ├── imm_maker      (immediate_maker)
│   ├── reg_file       (register_file)
│   └── funct_unit     (function_unit)
└── mem_16k (memory)
```

---

### top

Connects the core to the memory. The core fetches through `i_addr`/`i_data` and accesses data through `d_addr`/`d_data` of the same memory.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset (active high) |
| `test` | out | 1 | XOR of all core outputs; keeps logic from being removed in synthesis |

---

### single_cycle_core

Simple core. Execute main operation.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `instr` | in | 32 | Instruction read from memory at `pc` |
| `mem_load_data` | in | 32 | Data read from memory at `mem_addr` |
| `pc` | out | 32 | Current PC (instruction address) |
| `mem_addr` | out | 32 | Data address (ALU result) |
| `mem_write_data` | out | 32 | Store data (`rs2`) |
| `mem_byte` | out | 2 | Access size: byte, halfword, word |
| `mem_read`, `mem_write` | out | 1 | Load / store enable |


---

### PC

Program counter. Adds 4 to the PC every cycle.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Asynchronous reset to 0 |
| `PC_in` | in | 32 | Jump/branch target |
| `PC_write` | in | 1 | 1: load `PC_in`, 0: `PC + 4` |
| `PC_out` | out | 32 | Current PC |


---

### instr_decoder

Decode instruction, make address, decide detail operation. `ecall` and `ebreak` instructions are not detected here.

| Port | Dir | Width | Description |
|---|---|---|---|
| `instr` | in | 32 | Instruction |
| `aa`, `ba` | out | 5 | Source register numbers (`rs1`, `rs2`) |
| `da` | out | 5 | Destination register number (`rd`) |
| `funct_op` | out | 4 | ALU operation (see `funct_unit`) |
| `type_sel` | out | 3 | Immediate format: R/I/S/B/U/J |
| `Ma` | out | 1 | ALU input A: 0 = `rs1`, 1 = `PC` |
| `Mb` | out | 1 | ALU input B: 0 = `rs2`, 1 = immediate |
| `Mresult` | out | 2 | Write-back source: ALU, memory, `PC + 4`, immediate |
| `reg_write` | out | 1 | Write `rd` |
| `mem_read`, `mem_write` | out | 1 | Load / store |
| `mem_byte` | out | 2 | Access size |
| `sign_ext` | out | 1 | Sign-extend byte/halfword loads |
| `branch`, `jump`, `jalr` | out | 1 | Control flow type |
| `unidentified` | out | 1 | Unknown opcode |


---

### imm_maker

Builds the 32-bit immediate from the instruction type. It runs in parallel with `instr_decoder` and also detects `ecall` and `ebreak`.

| Port | Dir | Width | Description |
|---|---|---|---|
| `instr` | in | 32 | Instruction |
| `type_sel` | in | 3 | Immediate format from the decoder |
| `imm` | out | 32 | Sign-extended immediate (shift amount for `slli`/`srli`/`srai`) |
| `ecall`, `ebreak` | out | 1 | `ecall` / `ebreak` detected |


---

### reg_file

32 registers with `x0` fixed to 0. Two asynchronous read ports and one synchronous write port.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `aa`, `ba` | in | 5 | Read register numbers |
| `da` | in | 5 | Write register number |
| `write_data` | in | 32 | Write-back value |
| `reg_write` | in | 1 | Write enable |
| `rs1`, `rs2` | out | 32 | Read values |


---

### funct_unit

ALU unit. Does not do multiplication/division.

| Port | Dir | Width | Description |
|---|---|---|---|
| `in1`, `in2` | in | 32 | Operands |
| `funct_op` | in | 4 | Operation |
| `funct_out` | out | 32 | Result (compare operations return 0 or 1) |

| `funct_op` | Operation | `funct_op` | Operation |
|---|---|---|---|
| `ADD` | `in1 + in2` | `LESS` / `LESSU` | signed / unsigned `<` |
| `SUB` | `in1 - in2` | `LESS_EQL` | signed `<=` |
| `AND` `OR` `XOR` | bitwise | `GRT` | signed `>` |
| `SLL` `SRL` | logical shift | `GRT_EQL` / `GRT_EQLU` | signed / unsigned `>=` |
| `SRA` | arithmetic shift | `EQL` / `NOTEQL` | `==` / `!=` |


---

### mem_16k

16KB (4096 x 32-bit) memory shared by instruction fetch and data access.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock (writes only) |
| `i_addr` | in | 32 | Instruction address |
| `d_addr` | in | 32 | Data address |
| `write_data` | in | 32 | Store data |
| `mem_byte` | in | 2 | Access size |
| `mem_read`, `mem_write` | in | 1 | Load / store enable |
| `i_data` | out | 32 | Instruction (asynchronous read) |
| `d_data` | out | 32 | Load data (asynchronous read) |
| `miss_addr` | out | 1 | Misaligned address detected (not connected) |

## Verification

Passes 40 of 41 `rv32ui` tests from [riscv-tests](https://github.com/riscv-software-src/riscv-tests).

| Result | Tests |
|---|---|
| Pass | All except `ma_data` |
| Not supported | `ma_data`: misaligned load/store that crosses a word boundary |

A test passes if `gp` (`x3`) is 1 when `ecall` executes.

Unit testbenches:

- `sim/tb_function_unit.sv`
- `sim/tb_imm_maker.sv`

## Run simulation

Requires [Verilator](https://www.veripool.org/verilator/) 5.x.

```bash
cd sim
verilator --binary --timing -Wno-fatal --top-module tb_cpu \
  ../src/pkg_rv32i.sv ../src/function_unit.sv ../src/imm_maker.sv ../src/instr_decoder.sv \
  ../src/memory.sv ../src/program_counter.sv ../src/register_file.sv ../src/single-cycle.sv \
  ../src/top.sv tb_top.sv

./obj_dir/Vtb_cpu +HEX=../programs/rv32ui/add.hex
./obj_dir/Vtb_cpu +HEX=../programs/prog.hex +DUMP
```

| Option | Effect |
|---|---|
| `+HEX=<file>` | Hex file to load into memory (default `../programs/prog.hex`) |
| `+DUMP` | Print register values at the end |

Run all rv32ui tests:

```bash
for h in ../programs/rv32ui/*.hex; do
  printf "%-10s " $(basename $h .hex)
  ./obj_dir/Vtb_cpu +HEX=$h | grep -E "PASS|FAIL|TIMEOUT" | head -1
done
```

Build your own assembly into a hex file with the RISC-V GNU toolchain:

```bash
cd programs
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T link.ld prog.s -o prog.elf
riscv64-unknown-elf-objcopy -O binary prog.elf prog.bin
od -An -v -tx4 -w4 prog.bin | tr -d ' ' > prog.hex
```

## Synthesis

Vivado 2022.2, Artix-7 `xc7a35tcpg236-1`, after place and route. The clock constraint is in [`src/constraints.xdc`](src/constraints.xdc), and full reports are in [`synthesis/`](synthesis).

### Changes from the baseline

The baseline (before v1.0.1) had 32 latches on `d_data` in `mem_16k`, because `d_data` was not assigned when `mem_read` was 0. Vivado excluded every path through those latches from timing analysis, so the load path was never checked and the reported clock was too optimistic. v1.0.1 gives `d_data` a default value, which removes the latches.

| Item | Baseline | v1.0.1 |
|---|---|---|
| Latches | 32 | 0 |
| Global clock buffers | 2 (`clk`, `mem_read`) | 1 (`clk`) |
| Unconstrained endpoints (`check_timing`) | 32 | 0 |
| Clock period | 20.1 ns (49.8 MHz), load path not analyzed | 25.0 ns (40.0 MHz), all paths analyzed |
| Critical path | Store: memory write enable | Load: register file write |

The baseline reports are in the baseline commit on this branch.

### FPGA resources

| Resource | Used | Utilization |
|---|---|---|
| Slice | 1,803 | 22.1% |
| Slice LUT | 6,158 | 29.6% |
| LUT as Logic | 2,018 | 9.7% |
| LUT as Distributed RAM | 4,140 | 43.1% |
| Flip-Flop | 128 | 0.3% |
| Latch | 0 | 0% |
| Block RAM / DSP | 0 / 0 | 0% |

- The memory is synthesized as distributed RAM, not Block RAM, because its reads are asynchronous.
- The `test` output of `top` XORs the core outputs together so synthesis does not remove the logic.

### Resources by module

| Instance | Module | LUT (logic) | LUTRAM | FF |
|---|---|---|---|---|
| `core/program_counter` | `PC` | 1,381 | 0 | 127 |
| `core/register_file` | `reg_file` | 66 | 44 | 0 |
| `core/function_unit` | `funct_unit` | 9 | 0 | 0 |
| `memory` | `mem_16k` | 562 | 4,096 | 0 |

- Vivado optimizes across module boundaries, so `instr_decoder` and `imm_maker` do not appear separately. Their logic is counted under `program_counter`, along with most of the datapath.
- `PC` has 127 flip-flops instead of 32 because Vivado replicated PC bits to drive the large memory fan-out.
- The register file is also synthesized as distributed RAM (44 LUTRAMs).

### Power

| Item | Value |
|---|---|
| Total on-chip power | 0.089 W |
| Dynamic | 0.019 W |
| Device static | 0.070 W |
| Junction temperature | 25.4 °C |

Estimated without a simulation activity file (Vivado confidence level: Medium).

### Timing

| Item | Value |
|---|---|
| Clock period | 25.0 ns (40.0 MHz) |
| WNS (setup) | +0.005 ns |
| WHS (hold) | +0.304 ns |
| Result | All constraints met |

The critical path is the load path:

```
PC -> instruction read -> decode -> ALU -> data memory read -> write-back mux -> register file write
```

- Data path delay is 24.66 ns with 21 logic levels, including two memory reads.
- 83% of the delay is routing, because the 16KB memory is spread across thousands of LUTs.
- All of the 10 worst paths end at the register file write data, with slack between 0.005 and 0.090 ns.
- With only 0.005 ns of slack, 25.0 ns is close to the minimum period for this design.

`check_timing` reports only missing input/output delays on the top-level ports. The design has no pin or I/O standard constraints, so it is synthesized and routed for analysis only. DRC reports this as `NSTD-1` and `UCIO-1`, which block bitstream generation.

### Report files

| File | Contents |
|---|---|
| `util.txt` | Resource utilization (`report_utilization`) |
| `util_hier.txt` | Resource utilization by module (`report_utilization -hierarchical`) |
| `timing.txt` | Timing summary (`report_timing_summary`) |
| `critical_path.txt` | Critical path details (`report_timing -max_paths 1`) |
| `top10_paths.txt` | 10 worst paths (`report_timing -max_paths 10`) |
| `check.txt` | Timing constraint check (`check_timing`) |
| `clock_util.txt` | Clock buffer usage (`report_clock_utilization`) |
| `power.txt` | Power estimate (`report_power`) |
| `drc.txt` | Design rule check (`report_drc`) |

## Limitations

- Misaligned loads/stores that cross a word boundary are not supported.
- No exceptions, interrupts, or CSRs.
- Every instruction completes in one clock, so the clock period is set by the slowest instruction. The 5-stage pipelined version on the [`main` branch](https://github.com/tkfkatkdlwjd/RISC-V/tree/main) addresses this.
- The memory must be read asynchronously, so it cannot use Block RAM. Block RAM returns data one clock after the address, which would turn loads into 2-cycle instructions.
- Memory is synthesized at twice its size: 4,096 LUTs instead of 2,048 for 16KB. Instruction fetch and data access read different addresses in the same cycle, and a LUT RAM has only one read address, so Vivado keeps two copies of the memory.

This version is kept as a baseline for comparison with the pipelined core.
