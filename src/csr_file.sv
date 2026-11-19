module csr_file(
    input clk, rst, trap_valid, mret_valid,
    input csr_write, wen, instr_cnt,
    input [31:0] wdata, mepc_in, mcause_in, mtval_in,
    input [11:0] addr,
    output logic [31:0] rdata, mtvec_out, mepc_out,
    output logic illegal, no_count_flag
);
localparam logic [11:0] MSTATUS   = 12'h300; // 전역 상태: MIE(인터럽트 전역 enable), MPIE(trap 전 MIE 백업), MPP(trap 전 권한)
localparam logic [11:0] MISA      = 12'h301; // 지원 ISA 알림 (RV32 + I + M), 읽기 전용처럼 동작
localparam logic [11:0] MIE       = 12'h304; // 인터럽트별 enable (MSIE/MTIE/MEIE)
localparam logic [11:0] MTVEC     = 12'h305; // trap 핸들러 시작 주소 (BASE + MODE)
localparam logic [11:0] MSCRATCH  = 12'h340; // 핸들러가 임시로 쓰는 범용 레지스터 (보통 스택 포인터 보관)
localparam logic [11:0] MEPC      = 12'h341; // trap 걸린 명령의 PC. mret가 여기로 복귀
localparam logic [11:0] MCAUSE    = 12'h342; // trap 원인 (bit31=인터럽트 여부, 나머지=코드)
localparam logic [11:0] MTVAL     = 12'h343; // trap 부가 정보 (잘못된 주소, 불법 명령어 등)
localparam logic [11:0] MIP       = 12'h344; // 인터럽트 pending 상태 (하드웨어가 세움)

localparam logic [11:0] MCYCLE    = 12'hB00; // 사이클 카운터 하위 32비트 (RW)
localparam logic [11:0] MCYCLEH   = 12'hB80; // 사이클 카운터 상위 32비트 (RW)
localparam logic [11:0] MINSTRET  = 12'hB02; // 완료된 명령 수 하위 32비트 (RW)
localparam logic [11:0] MINSTRETH = 12'hB82; // 완료된 명령 수 상위 32비트 (RW)

localparam logic [11:0] CYCLE     = 12'hC00; // mcycle의 읽기 전용 shadow (하위)
localparam logic [11:0] CYCLEH    = 12'hC80; // mcycle의 읽기 전용 shadow (상위)
localparam logic [11:0] INSTRET   = 12'hC02; // minstret의 읽기 전용 shadow (하위)
localparam logic [11:0] INSTRETH  = 12'hC82; // minstret의 읽기 전용 shadow (상위)

localparam logic [11:0] MVENDORID = 12'hF11; // 제조사 ID (0 = 비상업/미지정)
localparam logic [11:0] MARCHID   = 12'hF12; // 마이크로아키텍처 ID (0 허용)
localparam logic [11:0] MIMPID    = 12'hF13; // 구현 버전 (0 허용)
localparam logic [11:0] MHARTID   = 12'hF14; // 하드웨어 스레드(코어) ID, 단일 코어면 0

// ---------- 상태 flop ----------
logic        mstatus_mie;   // mstatus[3]: 인터럽트 전역 enable. trap 진입 시 0, mret 시 MPIE로 복원
logic        mstatus_mpie;  // mstatus[7]: trap 직전 MIE 백업. mret 시 MIE로 복원 후 1
                            // (MPP[12:11]는 M-only라 2'b11 고정, flop 없음)

logic [31:0] mie;           // 인터럽트 enable. 유효 비트 MSIE(3), MTIE(7), MEIE(11), 나머지 0
logic [31:0] mtvec;         // trap 핸들러 주소. direct 모드만이라 [1:0]=0
logic [31:0] mscratch;      // SW 전용 임시 저장, 하드웨어는 안 건드림
logic [31:0] mepc;          // trap 시 PC 저장, mret 시 PC로 복원. [1:0]=0
logic [31:0] mcause;        // trap 시 원인 코드 저장
logic [31:0] mtval;         // trap 시 부가 정보 저장 (잘못된 주소/명령어, 없으면 0)

logic [63:0] mcycle, minstret;

// ---------- 읽기용 조합 신호 ----------
logic [31:0] mstatus_val;   // mstatus 조립값: {19'b0, 2'b11, 3'b0, mpie, 3'b0, mie, 3'b0}
logic [31:0] mip_val;       // mip 조립값: irq_meip/mtip/msip 입력을 bit 11/7/3에 배치 (SW 쓰기 불가)

assign mstatus_val = {19'b0, 2'b11, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
assign mip_val     = 32'b0;   // 인터럽트 입력 아직 없음

// ---------- 읽기 mux 출력 ----------
logic        addr_valid;    // 구현된 CSR 주소면 1, 아니면 0 → illegal instruction 판정에 사용

assign mtvec_out = mtvec;
assign mepc_out = mepc;

// 없는 CSR 접근, 또는 읽기 전용 CSR(addr[11:10]=11)에 실제 쓰기
assign illegal = csr_write && (!addr_valid || (wen && addr[11:10] == 2'b11));
assign no_count_flag = wen && !illegal && (addr == 12'hB02 || addr == 12'hB82);


always_comb begin
    rdata      = 32'b0;
    addr_valid = 1'b1;
    case (addr) inside
        12'h300 : rdata = mstatus_val;   // mstatus  : MIE / MPIE / MPP(=11 고정)
        12'h301 : rdata = 32'h4000_1100;  // misa     : MXL=1(RV32) | M(bit12) | I(bit8), 읽기 전용
        12'h304 : rdata = mie;            // mie      : MSIE(3) / MTIE(7) / MEIE(11)
        12'h305 : rdata = mtvec;          // mtvec    : trap 핸들러 주소 (direct 모드)
        12'h340 : rdata = mscratch;       // mscratch : 핸들러용 임시 저장
        12'h341 : rdata = mepc;           // mepc     : trap 걸린 명령의 PC, mret 복귀 주소
        12'h342 : rdata = mcause;         // mcause   : bit31=인터럽트 여부, 나머지=코드
        12'h343 : rdata = mtval;          // mtval    : 잘못된 주소/명령어, 없으면 0
        12'h344 : rdata = mip_val;        // mip      : 인터럽트 pending (하드웨어가 세움)

        // ---- 카운터 (M-mode RW와 U-mode 읽기 전용 shadow는 같은 값) ----
        12'hB00, 12'hC00 : rdata = mcycle[31:0];         // mcycle   / cycle
        12'hB80, 12'hC80 : rdata = mcycle[63:32];        // mcycleh  / cycleh
        12'hB02, 12'hC02 : rdata = minstret[31:0];       // minstret / instret
        12'hB82, 12'hC82 : rdata = minstret[63:32];      // minstreth/ instreth

        // ---- ID 레지스터: 값은 0, 존재는 해야 하므로 valid 유지 ----
        12'hF11, 12'hF12, 12'hF13, 12'hF14: rdata = 32'b0;   // mvendorid / marchid / mimpid / mhartid

        12'h310, 12'hF15,
        [12'h323:12'h33F],
        [12'hB03:12'hB1F],
        [12'hB83:12'hB9F] : rdata = 32'b0;

        default : addr_valid = 1'b0;
    endcase
end

always_ff @(posedge clk) begin
    if (trap_valid) begin
        mepc <= mepc_in;
        mcause <= mcause_in;
        mtval <= mtval_in;
        mstatus_mie  <= 0;
        mstatus_mpie <= mstatus_mie;
    end
    else if (mret_valid) begin
        mstatus_mie <= mstatus_mpie;
        mstatus_mpie <= 1;
    end
    else if (wen && !illegal) begin
        case (addr)
            12'h300: begin                                  // mstatus : MIE, MPIE만 쓰기 가능 (MPP=11 고정)
                mstatus_mie  <= wdata[3];
                mstatus_mpie <= wdata[7];
            end
            12'h301 : ;                                      // misa    : 읽기 전용처럼 동작, 쓰기 무시
            12'h304 : mie      <= wdata & 32'h0000_0888;     // mie     : MSIE(3) / MTIE(7) / MEIE(11)만 저장
            12'h305 : mtvec    <= {wdata[31:2], 2'b00};      // mtvec   : direct 모드만 → MODE[1:0]=0
            12'h340 : mscratch <= wdata;
            12'h341 : mepc     <= {wdata[31:2], 2'b00};      // mepc    : 명령어 4바이트 정렬 → [1:0]=0
            12'h342 : mcause   <= wdata;                     // mcause
            12'h343 : mtval    <= wdata;                     // mtval
            12'h344 : ;                                      // mip     : 하드웨어가 세움, SW 쓰기 무시
            12'hB00 : mcycle[31:0]    <= wdata;
            12'hB80 : mcycle[63:32]   <= wdata;
            12'hB02 : minstret[31:0]  <= wdata;
            12'hB82 : minstret[63:32] <= wdata;

            // cycle/instret shadow(Cxx), ID 레지스터(F1x)는 읽기 전용 → 쓰기 없음
            default: ;
        endcase
    end
    if (!(wen && !illegal && (addr == 12'hB00 || addr == 12'hB80)))
        mcycle <= mcycle + 1;
    if (!(wen && !illegal && (addr == 12'hB02 || addr == 12'hB82)) && instr_cnt)
        minstret <= minstret + 1;


    if (rst) begin
        mstatus_mie <= 1'b0;
    end
end

endmodule
