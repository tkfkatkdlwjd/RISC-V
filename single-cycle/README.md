# Single-Cycle RV32I

A 32-bit RISC-V single-cycle core written in SystemVerilog.

## Structure

```
        +----+   instr   +---------+  ctrl   +-------------------------+
  +---> | PC | --------> | decoder | ------> |  MUX_a / MUX_b -> ALU   |
  |     +----+     |     +---------+         +-------------------------+
  |                |     +---------+  imm         |              |
  |                +---> |   imm   | -------------+         mem_addr
  |                      +---------+                             v
  |                      +---------+  rs1/rs2              +----------+
  |                      | regfile | <-- write-back MUX <- |  memory  |
  |                      +---------+                       +----------+
  +---- PC+4 / branch / jal / jalr
```

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
- Clock period is 20.1 ns (about 49.8 MHz). The critical path is the store path through instruction fetch, decode, ALU, and memory write enable.
- The `ecall` instruction is used only to end the simulation.

## Modules

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

Program counter. every cycle add 4 to PC. 

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

Make 32bit immediate based on instruction type. `imm_maker` operate parellel with `instr_decoder`. Also detect `ecall` and `ebreak` instruction.

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

ALU unit. Does not multipication/division.

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

- `tb/tb_function_unit.sv`
- `tb/tb_imm_maker.sv`
- `tb/tb_instr_decoder.sv` (uses the instruction encoders in `tb/rv_asm_pkg.sv`)

## Run simulation

Requires [Verilator](https://www.veripool.org/verilator/) 5.x.

```bash
cd single-cycle
verilator --binary --timing -Wno-fatal --top-module tb_cpu \
  pkg_rv32i.sv function_unit.sv imm_maker.sv instr_decoder.sv memory.sv \
  program_counter.sv register_file.sv single-cycle.sv top.sv tb/tb_top.sv

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

Vivado 2022.2, Artix-7 `xc7a35tcpg236-1`, after place and route. Full reports are in [`synthesis/`](synthesis).

### FPGA resources

| Resource | Used | Utilization |
|---|---|---|
| Slice LUT | 6,195 | 29.8% |
| LUT as Logic | 2,055 | 9.9% |
| LUT as Distributed RAM | 4,140 | 43.1% |
| Flip-Flop | 137 | 0.3% |
| Latch | 32 | - |
| Block RAM / DSP | 0 / 0 | 0% |

- The memory is synthesized as distributed RAM, not Block RAM, because its reads are asynchronous.
- The `test` output of `top` XORs the core outputs together so synthesis does not remove the logic.
- The 32 latches come from `d_data` in `mem_16k`, which is not assigned when `mem_read` is 0.

### Resources by module

| Instance | Module | LUT (logic) | LUTRAM | FF / Latch |
|---|---|---|---|---|
| `core/program_counter` | `PC` | 1,464 | 0 | 136 |
| `core/register_file` | `reg_file` | 27 | 44 | 0 |
| `core/function_unit` | `funct_unit` | 13 | 0 | 0 |
| `memory` | `mem_16k` | 551 | 4,096 | 32 |

- Vivado optimizes across module boundaries, so `instr_decoder` and `imm_maker` do not appear separately. Their logic is counted under `program_counter`, along with most of the datapath.
- `PC` has 136 flip-flops instead of 32 because Vivado replicated PC bits to drive the large memory fan-out.
- The register file is also synthesized as distributed RAM (44 LUTRAMs).

### Power

| Item | Value |
|---|---|
| Total on-chip power | 0.094 W |
| Dynamic | 0.024 W |
| Device static | 0.070 W |
| Junction temperature | 25.5 °C |

Estimated without a simulation activity file (Vivado confidence level: Medium).

### Timing

| Item | Value |
|---|---|
| Clock period | 20.1 ns (about 49.8 MHz) |
| WNS (setup) | +0.048 ns |
| WHS (hold) | +0.339 ns |
| Result | All constraints met |

The critical path is the store path:

```
PC -> instruction read -> decode -> immediate -> ALU -> memory address -> memory write enable
```

- Data path delay is 19.45 ns with 17 logic levels.
- 81% of the delay is routing, because the 16KB memory is spread across thousands of LUTs.
- All of the 10 worst paths end at a memory write enable, with slack between 0.048 and 0.106 ns.

Paths through the `d_data` latches are excluded from timing analysis (`check_timing`: 32 unconstrained endpoints), so the load path is not verified by these results. The clock report shows why: `mem_read` drives a second global clock buffer (`mem_read_BUFG`) that opens and closes those 32 latches.

The design has no pin or I/O standard constraints, so it is synthesized and routed for analysis only. DRC reports this as `NSTD-1` and `UCIO-1`, which block bitstream generation.

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
- Timing of the load path is not analyzed because of the `d_data` latches.
- Every instruction completes in one clock, so the clock period is set by the slowest instruction. The 5-stage pipelined version in [`pipelined/`](https://github.com/tkfkatkdlwjd/RISC-V/tree/main/pipelined) on the `main` branch addresses this.
