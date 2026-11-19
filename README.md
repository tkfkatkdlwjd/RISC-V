# 5-Stage Pipelined RV32IM

A 32-bit RISC-V 5-stage pipelined core written in SystemVerilog. It supports RV32I, the M extension (multiply/divide), Zicsr, and M-mode traps.

## Structure

![Pipelined datapath](docs/datapath.svg)

| Stage | Work | Pipeline register |
|---|---|---|
| IF | Fetch the instruction at PC | `pipereg_if` (IF/ID) |
| ID | Decode, read registers, compute `jal` target | `pipereg_id` (ID/EX) |
| EX | ALU, multiply/divide, branch decision, `jalr` target, CSR read/write | `pipereg_ex` (EX/MEM) |
| MEM | Load/store, byte/halfword sign extension, `PC + 4` for `jal`/`jalr` | `pipereg_mem` (MEM/WB) |
| WB | Register write, commit traps | - |

The `_F/_D/_E/_M/_W` suffix on a signal name tells which stage the signal belongs to.

## Features

- 32-bit RISC-V 5-stage pipelined CPU core.
- Supports RV32I, the M extension, and Zicsr. `fence`, `fence.i`, and `wfi` run as no-ops.
- M-mode traps for `ecall`, `ebreak`, illegal instructions, and misaligned addresses, with `mret` to return.
- Data hazards are handled by forwarding, with a 1-cycle stall for load-use.
- No branch prediction; branches are resolved in EX.
- No cache; 16KB memory by default (`STORAGE` parameter), shared by instruction fetch and data access.
- Clock period is 11.25 ns (88.9 MHz), 2.22x the clock of the single-cycle version.

## Versions

### v2.1.0

- Add the M extension: `multiplier` (radix-4 Booth) and `divider` (restoring).
- Add Zicsr and `csr_file`.
- Add M-mode traps and `mret`.
- Fix illegal instructions detection in `instr_decoder`, including undefined funct3/funct7 combinations.
- Compute the `jal`/`jalr` return address in MEM (`next_PC_M`) instead of WB.
- Keep `PC + 4` separate from the next-PC mux (`keep`), and replicate forwarding flags (`max_fanout`).
- Change the clock constraint from 13.25 ns to 11.25 ns.

### v2.0.1

- Add README.
- Fix latches on `d_data` in `memory`.
- Add `test` output to `top` for synthesis.
- Add Vivado synthesis reports.
- Move design files to `src/` and testbenches to `sim/`.

## Directory structure

| Folder | Contents |
|---|---|
| [`src/`](src) | SystemVerilog design files and the clock constraint (`constraints.xdc`) |
| [`sim/`](sim) | CPU testbench (`tb_core.sv`) and unit testbenches |
| [`programs/`](programs) | Test programs (hex), a sample program, and linker scripts |
| [`synthesis/`](synthesis) | Vivado utilization, timing, power, and DRC reports |
| [`docs/`](docs) | Datapath diagram |

## Supported instructions

| Type | Instructions |
|---|---|
| RV32I | Arithmetic/logic, immediate, load/store, branch, `jal` `jalr` `lui` `auipc` |
| M extension | `mul` `mulh` `mulhsu` `mulhu` `div` `divu` `rem` `remu` |
| Zicsr | `csrrw` `csrrs` `csrrc` `csrrwi` `csrrsi` `csrrci` |
| System | `ecall` `ebreak` `mret`; `fence` / `fence.i` / `wfi` (no-op) |

## Hazard handling

Hazards are detected in the ID stage. A forwarding flag is set when the instruction in the ID stage reads a register that an older instruction will write, and the flag then moves down the pipeline with that older instruction. In flag names, `1` and `2` mean the distance between matched instructions, and the suffix is the stage the flag belongs to (`_E` -> `_M` -> `_W`).

### Detection

| Signal | Role |
|---|---|
| `rs1_hit1`, `rs2_hit1` | `rs1`/`rs2` of the instruction in ID matches `rd` of the instruction in EX (1 ahead) |
| `rs1_hit2`, `rs2_hit2` | Matches `rd` of the instruction in MEM (2 ahead), only when there is no `hit1` |

### Data forwarding

| Signal | Older instruction | Role |
|---|---|---|
| `rs1_forward1_E`, `rs2_forward1_E` | ALU, 1 ahead | Next cycle, the ALU input takes `funct_out_M` from EX/MEM |
| `lui_M` | `lui`, 1 ahead | With `forward1`, take `imm_M` instead of `funct_out_M` |
| `rs1_forward2_M`, `rs2_forward2_M` | ALU, 2 ahead | Next cycle, the ALU input takes the write-back value `reg_write_data` |
| `mem1_forward1_E`, `mem2_forward1_E` | Load, 1 ahead | Stall 1 cycle, then the ALU input takes the loaded value `reg_write_data` |
| `mem1_forward2_M`, `mem2_forward2_M` | Load, 2 ahead | Next cycle, the ALU input takes the loaded value `reg_write_data` |

An instruction 3 ahead is in WB while the instruction reads registers in ID, so the register file passes `write_data` straight to the read port.

The multiplier, divider, and CSR operand use the same forwarded ALU inputs.

### Store data forwarding

The store data register is read in ID but used in MEM, so it is replaced in the MEM stage instead of at the ALU input. These flags move with the store instruction, so they start with `_D`.

| Signal | Older instruction | Role |
|---|---|---|
| `sw_data_forward1_D` | 1 ahead | In MEM, the store data takes `reg_write_data` |
| `sw_data_forward2_D` | 2 ahead | In MEM, the store data takes `write_data_buffer` |
| `write_data_buffer` | | `reg_write_data` delayed by one cycle |

### Stall and flush

| Signal | Set when | Role |
|---|---|---|
| `stall_if`, `stall_id` | Load-use (`mem*_forward1_E`) | Hold the PC and the IF/ID register for one cycle |
| `flush_ex` | Load-use | Insert a bubble into ID/EX |
| `stall_if`, `stall_id`, `stall_ex` | Multiply or divide in EX until `done` | Hold IF through EX |
| `flush_mem` | Multiply or divide in EX until `done` | Insert bubbles into EX/MEM |
| `stall_if`, `stall_id` | CSR instruction in ID while older instructions are in EX, MEM, or WB | Wait until the pipeline is empty |
| `flush_id` | `jal` in ID (`jump_fire_D`) | Discard the instruction fetched after `jal` |
| `flush_id`, `flush_ex` | Taken branch or `jalr` in EX | Discard the two instructions fetched after it |
| `flush_*` | Trap or `mret` in EX, MEM, or WB | Discard all younger instructions |
| `PC_write`, `PC_in` | `jal`, taken branch, `jalr`, trap, `mret` | Load the target, `mtvec`, or `mepc` into the PC |

`jump_fire_D` is `jump_D` only when ID is not stalled, so a `jal` held by a stall does not redirect the PC twice.

## Traps (M-mode)

Traps are committed in the WB stage. Older instructions complete, and all younger instructions are discarded (precise traps). The trapping instruction does not write registers, memory, or CSRs.

| `mcause` | Cause | `mtval` |
|---|---|---|
| 0 | Instruction address misaligned (`jal`, `jalr`, branch target) | Target address |
| 2 | Illegal instruction | 0 |
| 3 | `ebreak` | 0 |
| 4 | Load address misaligned | Access address |
| 6 | Store address misaligned | Access address |
| 11 | `ecall` from M-mode | 0 |

- On a trap, the PC is saved to `mepc` and execution jumps to `mtvec`. `mret` returns to `mepc`.
- Misaligned loads/stores are not handled in hardware; they trap.
- `mtvec` supports direct mode only.

### Implemented CSRs

| Type | CSRs |
|---|---|
| Trap | `mstatus` `mtvec` `mepc` `mcause` `mtval` `mscratch` |
| Interrupt | `mie` `mip` (registers only; no interrupt inputs) |
| Counter | `mcycle(h)` `minstret(h)`, read-only `cycle(h)` `instret(h)` |
| Information | `misa` (RV32IM), `mvendorid` `marchid` `mimpid` `mhartid` (all 0) |

Accessing a CSR that does not exist, or writing a read-only CSR, raises an illegal instruction trap.

## Modules

File paths below are relative to [`src/`](src).

| File | Module | Description |
|---|---|---|
| `top.sv` | `top` | Connects the core and memory |
| `core.sv` | `pipelined_core` | Pipeline, hazard detection, forwarding, next-PC logic, traps |
| `pipereg_if/id/ex/mem.sv` | `pipereg_*` | Pipeline registers between stages (stall and flush) |
| `instr_decoder.sv` | `instr_decoder` | Decodes instructions into control signals and immediates, detects illegal instructions |
| `function_unit.sv` | `funct_unit` | Arithmetic, logic, shift, and compare operations |
| `multiplier.sv` | `multiplier` | Radix-4 Booth multiplier (`mul_exe` inside) |
| `divider.sv` | `divider` | Restoring divider |
| `csr_file.sv` | `csr_file` | CSRs, trap state, counters |
| `register_file.sv` | `reg_file` | 32 x 32-bit registers (`x0` = 0), with WB -> ID bypass |
| `program_counter.sv` | `PC` | PC register |
| `memory.sv` | `memory` | 16KB instruction/data memory |
| `pkg_rv32i.sv` | `rv32i` | Opcodes, operation codes, mux select constants |

## Module details

### Hierarchy

```
top
├── pipelined_core (core)
│   ├── PC             (program_counter)
│   ├── pipereg_if     (if_id)
│   ├── instr_decoder  (decoder)
│   ├── reg_file       (register_file)
│   ├── pipereg_id     (id_ex)
│   ├── funct_unit     (alu)
│   ├── multiplier     (mul_function)
│   │   └── mul_exe    (mul_execution)
│   ├── divider        (div_function)
│   ├── csr_file       (csr_file)
│   ├── pipereg_ex     (ex_mem)
│   └── pipereg_mem    (mem_wb)
└── memory (memory_16k)
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

### pipelined_core

5-stage pipelined core. Execute main operation.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `instr` | in | 32 | Instruction read from memory at `pc` |
| `mem_load_data` | in | 32 | Data read from memory at `mem_addr` |
| `pc` | out | 32 | PC of the IF stage |
| `mem_addr` | out | 32 | Data address (ALU result of the MEM stage) |
| `mem_write_data` | out | 32 | Store data |
| `mem_byte` | out | 2 | Access size: byte, halfword, word |
| `mem_read`, `mem_write` | out | 1 | Load / store enable (0 for a misaligned access) |

---

### PC

Program counter. Adds 4 to PC every cycle, unless `stall` holds it. `PC + 4` is kept as a separate signal (`keep`) so that synthesis does not merge it with the next-PC mux.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Asynchronous reset to 0 |
| `PC_in` | in | 32 | Jump, branch, or trap target |
| `PC_write` | in | 1 | 1: load `PC_in` |
| `stall` | in | 1 | 1: hold the PC (`PC_write` takes priority) |
| `PC_out` | out | 32 | Current PC |

---

### instr_decoder

Decodes the instruction into register numbers, control signals, and the ALU operation. Unlike the single-cycle version, it also builds the immediate. For an undefined encoding, it sets `unidentified` and `trap` and forces all write signals to 0.

| Port | Dir | Width | Description |
|---|---|---|---|
| `instr` | in | 32 | Instruction |
| `rs1`, `rs2` | out | 5 | Source register numbers (0 if the instruction does not use them) |
| `rd` | out | 5 | Destination register number |
| `imm` | out | 32 | Sign-extended immediate (shift amount for `slli`/`srli`/`srai`) |
| `funct_op` | out | 4 | ALU operation (see `funct_unit`) |
| `Ma` | out | 1 | ALU input A: 0 = `rs1`, 1 = `PC` |
| `Mb` | out | 1 | ALU input B: 0 = `rs2`, 1 = immediate |
| `Mresult` | out | 2 | Write-back source: ALU, memory, `PC + 4`, immediate |
| `reg_write` | out | 1 | Write `rd` |
| `mem_read`, `mem_write` | out | 1 | Load / store |
| `mem_byte` | out | 2 | Access size |
| `sign_ext` | out | 1 | Sign-extend byte/halfword loads |
| `branch`, `jump`, `jalr` | out | 1 | Control flow type |
| `lui` | out | 1 | `lui` instruction (selects the immediate when forwarding) |
| `mul`, `div` | out | 1 | M extension multiply / divide |
| `mext_funct` | out | 2 | M extension operation (`funct3[1:0]`) |
| `csr_write` | out | 1 | CSR instruction |
| `csr_wen` | out | 1 | Actually write the CSR (`csrrs/c` only when `rs1`/uimm is not 0) |
| `csr_addr` | out | 12 | CSR address |
| `csr_op` | out | 3 | CSR operation (`funct3`) |
| `csr_imm` | out | 5 | uimm of `csrr*i` |
| `ecall`, `ebreak`, `mret` | out | 1 | System instructions |
| `unidentified` | out | 1 | Undefined opcode, funct3, or funct7 combination |
| `trap` | out | 1 | This instruction raises a trap (`ecall`, `ebreak`, illegal) |

---

### funct_unit

ALU unit. Does not do multiplication/division.

| Port | Dir | Width | Description |
|---|---|---|---|
| `in1`, `in2` | in | 32 | Operands |
| `funct_op` | in | 4 | Operation |
| `alu_out` | out | 32 | Result (compare operations return 0 or 1) |

| `funct_op` | Operation | `funct_op` | Operation |
|---|---|---|---|
| `ADD` | `in1 + in2` | `LESS` / `LESSU` | signed / unsigned `<` |
| `SUB` | `in1 - in2` | `LESS_EQL` | signed `<=` |
| `AND` `OR` `XOR` | bitwise | `GRT` | signed `>` |
| `SLL` `SRL` | logical shift | `GRT_EQL` / `GRT_EQLU` | signed / unsigned `>=` |
| `SRA` | arithmetic shift | `EQL` / `NOTEQL` | `==` / `!=` |

The core combines `alu_out` with the multiply, divide, and CSR results into `funct_out_E`.

---

### multiplier

Radix-4 Booth multiplier. It takes 17 steps after `en`, while the core stalls IF through EX.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `en` | in | 1 | Start (multiply instruction in EX) |
| `in1`, `in2` | in | 32 | Operands |
| `mul_op` | in | 2 | `mul`, `mulh`, `mulhsu`, `mulhu` |
| `result` | out | 32 | Lower or upper 32 bits of the product |
| `busy` | out | 1 | Multiplication in progress |
| `done` | out | 1 | `result` is valid |

---

### divider

Restoring divider. It takes 32 steps after `en`; division by zero finishes immediately with the result defined by the RISC-V spec.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `en` | in | 1 | Start (divide instruction in EX) |
| `in1`, `in2` | in | 32 | Dividend, divisor |
| `div_op` | in | 2 | `div`, `divu`, `rem`, `remu` |
| `result` | out | 32 | Quotient or remainder |
| `busy` | out | 1 | Division in progress |
| `done` | out | 1 | `result` is valid |

---

### csr_file

CSR registers, trap state, and the cycle/instruction counters. CSR instructions read and write it in EX; traps and `mret` update it in WB.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `csr_write` | in | 1 | CSR instruction in EX |
| `wen` | in | 1 | Write the CSR at `addr` |
| `addr` | in | 12 | CSR address |
| `wdata` | in | 32 | Write value (after the set/clear operation) |
| `trap_valid` | in | 1 | Trap committed in WB: save `mepc`, `mcause`, `mtval`, update `mstatus` |
| `mret_valid` | in | 1 | `mret` committed in WB: restore `mstatus` |
| `instr_cnt` | in | 1 | An instruction retired (increments `minstret`) |
| `mepc_in`, `mcause_in`, `mtval_in` | in | 32 | Trap values from WB |
| `rdata` | out | 32 | Read value |
| `mtvec_out`, `mepc_out` | out | 32 | Trap target and return address |
| `illegal` | out | 1 | CSR does not exist, or a read-only CSR is written |
| `no_count_flag` | out | 1 | This instruction writes `minstret(h)`, so it is not counted |

---

### reg_file

32 registers with `x0` fixed to 0. Two asynchronous read ports and one synchronous write port. If a register is written and read in the same cycle, `write_data` is passed straight to the output (WB -> ID bypass).

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rs1`, `rs2` | in | 5 | Read register numbers |
| `rd` | in | 5 | Write register number |
| `write_data` | in | 32 | Write value |
| `reg_write` | in | 1 | Write enable |
| `rs1_data`, `rs2_data` | out | 32 | Read values |

---

### memory

16KB (4096 x 32-bit) memory shared by instruction fetch and data access. The size is set by the `STORAGE` parameter (bytes, default 16384).

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
| `miss_addr` | out | 1 | Misaligned address detected (not connected; the core checks alignment in EX) |

## Verification

| Test | Coverage | Result | Cycles |
|---|---|---|---|
| `rv32ui` ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)) | RV32I instructions | 40 / 41 | 12,768 |
| `rv32um` (riscv-tests) | M extension | 8 / 8 | 6,263 |
| `zicsr_all` | Zicsr instructions and CSR behavior | Pass | 1,858 |
| `mz_all` | M, Zicsr, traps, hazards, reserved encodings | Pass | 27,872 |

Cycles for `rv32ui` and `rv32um` are the totals over the passing tests.

`rv32ui/ma_data` assumes misaligned accesses are handled in hardware. This core traps on them instead, so the test does not apply.

Unit testbenches:

- `sim/tb_function_unit.sv` (ALU, same as the single-cycle version)
- `sim/tb_multiplier.sv`
- `sim/tb_divider.sv`

## Run simulation

Requires [Verilator](https://www.veripool.org/verilator/) 5.x.

```bash
cd sim
verilator --binary --timing -Wno-fatal --top-module tb_core \
  ../src/pkg_rv32i.sv $(ls ../src/*.sv | grep -v pkg_rv32i.sv) tb_core.sv

./obj_dir/Vtb_core +HEX=../programs/rv32ui/add.hex
./obj_dir/Vtb_core +HEX=../programs/mz_all.hex +TOHOST=3680 +FAILLOG=3700
```

| Option | Effect |
|---|---|
| `+HEX=<file>` | Hex file to load into memory (default `../programs/prog.hex`) |
| `+DUMP` | Print register values at the end |
| `+TRACE` | Print PC and register writes in retirement order |
| `+TOHOST=<addr>` | Decide PASS/FAIL from the `tohost` address (hex) of the official riscv-tests environment |
| `+FAILLOG=<addr>` | Address (hex) where failing check numbers are recorded |

Without `+TOHOST`, a test passes if `gp` (`x3`) is 1 when `ecall` reaches WB.

## Synthesis

Vivado 2022.2, Artix-7 `xc7a35tcpg236-1`, after place and route. The clock constraint is in [`src/constraints.xdc`](src/constraints.xdc), and full reports are in [`synthesis/`](synthesis). The same chip, tool, and report commands were used for the [single-cycle version](https://github.com/tkfkatkdlwjd/RISC-V/tree/single-cycle), so the results can be compared directly.

### Comparison with previous versions

All versions use the same 16KB memory and have no latches. v1.0.1 and v2.0.1 are RV32I; v2.1.0 adds the M extension, Zicsr, and traps.

| Item | Single-cycle v1.0.1 | Pipelined v2.0.1 | Pipelined v2.1.0 |
|---|---|---|---|
| Clock period | 25.0 ns (40.0 MHz) | 13.25 ns (75.5 MHz) | **11.25 ns (88.9 MHz)** |
| Critical path delay | 24.66 ns | 12.44 ns | 11.13 ns |
| Routing share of the critical path | 83% | 59% | 73% |
| Slice | 1,803 | 1,834 | 2,169 |
| LUT as Logic | 2,018 | 1,971 | 3,138 |
| LUT as Distributed RAM | 4,140 | 4,140 | 4,140 |
| Flip-Flop | 128 | 914 | 1,637 |
| Dynamic power (estimate) | 0.019 W | 0.029 W | 0.019 W |

- From v2.0.1 to v2.1.0, the clock is 1.18x faster. Two adders were removed from the critical path: the `jal`/`jalr` return address (`PC + 4`) is now computed in MEM instead of WB, and the next sequential PC (`PC + 4`) is computed before the branch decision instead of after it.
- The extra logic in v2.1.0 is mostly the multiplier, divider, and CSR file (see [Resources by module](#resources-by-module)).

### Performance

Measured on the 40 passing `rv32ui` tests. Cycle counts come from simulation; the clock period comes from synthesis.

| | Single-cycle v1.0.1 | Pipelined v2.0.1 | Pipelined v2.1.0 |
|---|---|---|---|
| Instructions | 11,472 | 11,472 | 11,472 |
| Cycles | 11,472 | 12,768 | 12,768 |
| CPI | 1.00 | 1.11 | 1.11 |
| Execution time | 286.8 µs | 169.2 µs | 143.6 µs |
| Speedup | | 1.70x | **2.00x** |

- v2.1.0 runs `rv32ui` in the same number of cycles as v2.0.1; the speedup comes from the faster clock.
- Stalls and branch flushes raise CPI by 11%.
- The `rv32ui` tests compare results with a branch after almost every check, so they have more branches than a typical program. Cycle counts also include 4 cycles per test to fill the pipeline.

### Benchmarks

Dhrystone 2.2 (from [riscv-tests](https://github.com/riscv-software-src/riscv-tests)) and [CoreMark](https://github.com/eembc/coremark), compiled with GCC 14.2 `-O2` and run in simulation. Cycle counts cover only the timed part of each benchmark, and the clock comes from synthesis.

| | Single-cycle v1.0.1 | Pipelined v2.0.1 | Pipelined v2.1.0 |
|---|---|---|---|
| Build | `rv32i` | `rv32i` | `rv32im` |
| Dhrystone cycles per run | 591 | 787 | 801 |
| DMIPS/MHz | 0.963 | 0.723 | 0.711 |
| DMIPS | 38.5 | 54.6 | **63.2** |
| CoreMark iterations | 550 | 730 | 1,600 |
| CoreMark cycles per iteration | 747,083 | 1,056,205 | 567,420 |
| CoreMark/MHz | 1.339 | 0.947 | **1.762** |
| CoreMark | 53.5 | 71.5 | **156.7** |
| CoreMark run time at the synthesized clock | 10.27 s | 10.22 s | 10.21 s |

- The build is the compiler's `-march` option. v1.0.1 and v2.0.1 have no multiply/divide instructions, so they run the `rv32i` build; v2.1.0 runs the `rv32im` build.
- DMIPS/MHz and CoreMark/MHz measure work per clock cycle, so the pipelined cores score lower than the single-cycle core. Their faster clocks still make them faster overall.
- With the `rv32i` build, v2.1.0 takes exactly the same cycles as v2.0.1 (787 and 1,056,204), so it scores 64.3 DMIPS and 84.2 CoreMark from the clock alone. The M extension raises CoreMark further, to 156.7. Dhrystone has only a few multiplies and divides per run with small operands, so it does not gain from the hardware multiplier and divider.

Where the cycles go on pipelined v2.1.0 (share of all cycles in the timed run):

| | Dhrystone | CoreMark |
|---|---|---|
| Executing instructions | 70.0% | 55.3% |
| Taken branch (2 cycles each) | 14.5% | 11.5% |
| `jalr` (2 cycles each) | 3.7% | 0.8% |
| `jal` (1 cycle each) | 2.2% | 0.7% |
| Load-use stall | 3.1% | 3.6% |
| Multiply/divide stall | 6.4% | **28.2%** |
| CPI | 1.43 | 1.81 |

Notes:

- The cores have no C library, timer, or UART, so the benchmarks use a minimal `printf` and simple byte-by-byte string functions. The testbench prints characters and supplies the cycle count through reserved addresses at the top of memory.
- Dhrystone runs 500 times. Its results are checked inside the program against the expected final values.
- CoreMark follows the run rules: each run lasts at least 10 seconds at the synthesized clock, and both the 2K performance run (seeds `0, 0, 0x66`) and the 2K validation run (seeds `0x3415, 0x3415, 0x66`) report "Correct operation validated". The scores come from simulation, not from hardware, so they are not submitted to EEMBC.

### FPGA resources

| Resource | Used | Utilization |
|---|---|---|
| Slice | 2,169 | 26.6% |
| Slice LUT | 7,278 | 35.0% |
| LUT as Logic | 3,138 | 15.1% |
| LUT as Distributed RAM | 4,140 | 43.1% |
| Flip-Flop | 1,637 | 3.9% |
| Latch | 0 | 0% |
| Block RAM / DSP | 0 / 0 | 0% |

- The memory is synthesized as distributed RAM, not Block RAM, because its reads are asynchronous.
- The multiplier and divider are built from LUTs, not DSP blocks.
- The `test` output of `top` XORs the core outputs together so synthesis does not remove the logic.

### Resources by module

| Instance | Module | LUT (logic) | LUTRAM | FF |
|---|---|---|---|---|
| `core/program_counter` | `PC` | 8 | 0 | 91 |
| `core/if_id` | `pipereg_if` | 163 | 0 | 65 |
| `core/id_ex` | `pipereg_id` | 577 | 0 | 185 |
| `core/ex_mem` | `pipereg_ex` | 404 | 0 | 427 |
| `core/mem_wb` | `pipereg_mem` | 1,063 | 0 | 231 |
| `core/mul_function` | `multiplier` | 151 | 0 | 174 |
| `core/div_function` | `divider` | 191 | 0 | 140 |
| `core/csr_file` | `csr_file` | 0 | 0 | 291 |
| `core/register_file` | `reg_file` | 0 | 44 | 0 |
| `memory_16k` | `memory` | 584 | 4,096 | 0 |

- Vivado optimizes across module boundaries, so the decoder, ALU, forwarding, and hazard logic are counted under the pipeline registers. `function_unit` shows 0 for the same reason.
- `PC` has 91 flip-flops instead of 32 because Vivado replicated PC bits to drive the large memory fan-out.
- `csr_file` shows 0 LUTs for the same reason; its read and write logic is counted elsewhere.

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
| Clock period | 11.25 ns (88.9 MHz) |
| WNS (setup) | +0.013 ns |
| WHS (hold) | +0.054 ns |
| Result | All constraints met |

The critical path starts at a forwarding flag in the MEM/WB register and ends at the PC, within one clock:

```
rs2_forward2_W -> forwarding mux -> ALU compare -> branch condition
               -> branch decision -> next PC mux -> PC
```

| Segment | Delay | What it does |
|---|---|---|
| Forwarding flag and mux | 4.64 ns | Select the forwarded value for the ALU input in EX |
| ALU compare | 2.46 ns | Compare the operands (3 carry chains) |
| Branch condition | 1.09 ns | Pick the result for the branch type |
| Branch decision | 1.14 ns | `branch_E && condition` -> `PC_write` |
| Next PC mux | 1.80 ns | Choose the branch target or `PC + 4` |

- Data path delay is 11.13 ns with 14 logic levels; 27% is logic and 73% is routing.
- The only adder on the path is the ALU compare. The branch target and `PC + 4` are computed in parallel and only selected after the branch decision.
- The forwarding mux takes 4 LUT levels because `funct_in` checks the forwarding cases one after another.
- The forwarding flags are replicated (`max_fanout`) so that each copy drives fewer mux inputs. Without this, one flag drove 174 inputs.
- All of the 10 worst paths start at `rs2_forward2_W`, with slack between 0.013 and 0.123 ns. One ends at the PC; the others end at the flush (reset) pins of the IF/ID and ID/EX registers, which use the same branch decision.

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

- Misaligned loads/stores trap instead of being handled in hardware.
- No branch prediction; every taken branch or `jalr` costs 2 cycles, and every `jal` costs 1 cycle.
- The front of the pipeline (IF through EX) stalls during a multiply (17 steps) or divide (32 steps).
- No interrupt inputs; `mie` and `mip` are registers only.
- The memory is read asynchronously, so it uses distributed RAM instead of Block RAM. It is also synthesized at twice its size (4,096 LUTs instead of 2,048), because instruction fetch and data access read different addresses in the same cycle.
