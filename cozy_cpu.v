`default_nettype none

module cozy_cpu (
    input wire clk,
    input wire reset_n,

    input wire [7:0] inport,
    output wire [7:0] outport,

    output wire [15:0] out_pc,
    output wire [3:0] out_state,
    output wire [15:0] out_insn
);

reg [7:0] outport_r;

reg [15:0] pc;
reg [15:0] nextpc;

reg [2:0] cond;
wire cZ, cN, cC; assign {cZ, cN, cC} = cond;

wire [15:0] mem_dout;
wire [1:0] mem_bwe;
reg [15:0] mem_addr;

wire [15:0] alu_out;
wire alu_cout;

reg [15:0] rDi;
wire rDw;
wire [15:0] rD, rS;

// Latched instruction -- required to make multi-cycle operations work
reg [15:0] insn_latch;
wire insn_latch_sel;
wire [15:0] insn = insn_latch_sel ? insn_latch : mem_dout;

reg [3:0] state;
reg [17:0] ctl;

cozy_memory #( .BITS(8) ) MEM (
    .clk    (clk),
    .addr   (mem_addr),
    .din    (rD),
    .bwe    (mem_bwe),
    .dout   (mem_dout)
);

wire [15:0] ccg_out;
cozy_constant_generator CCG (
    .insn   (insn),
    .out    (ccg_out)
);

// Condition evaluation
reg cond_true;
always @(*)
    case (insn[11:9])
        3'b000: cond_true =  cZ;        // eq
        3'b001: cond_true = !cZ;        // ne
        3'b010: cond_true =  cN;        // lt
        3'b011: cond_true = !cN;        // ge
        3'b100: cond_true =  cN ||  cZ; // le
        3'b101: cond_true = !cN || !cZ; // gt
        3'b110: cond_true =   0;        // FIXME: unused
        3'b111: cond_true =   1;        // always
    endcase

cozy_registerfile REG (
    .clk    (clk),
    .rD_sel (insn[11:8]),
    .rD_in  (rDi),
    .rD_we  (rDw),
    .rD_out (rD),
    .rS_sel (insn[7:4]),
    .rS_out (rS)
);

cozy_alu ALU (
    .rD         (rD),
    .rS         (rS),
    .carry_in   (cC),
    .op         (insn[3:0]),
    .out        (alu_out),
    .carry_out  (alu_cout)
);

// Control values:
//  rDw
//  rDi select: 00=ccg, 01=alu, 10=pc, 11=mem
//  mem addr select: 000=nextpc, 001=nextpc+simm, 010=rD+imm4, 011=rD+imm4s1... 111=0 (for reset)
//  PC select: 00=keep, 01=nextpc, 10=nextpc+imm, 11=rS?

wire [3:0] next_state;
// rDw defined elsewhere
wire sel_ccw;
wire [2:0] sel_rdi;
wire [2:0] sel_maddr;
// mem_bwe defined elsewhere
wire [1:0] sel_pc;
wire sel_jump;
wire sel_outport;

assign {next_state, rDw, sel_ccw, sel_rdi, sel_maddr, mem_bwe, sel_pc, sel_jump, sel_outport} = ctl;

always @(*)
    casez ({ state, insn })
        //SSSS IIII IIII IIII IIII          SSSS Wc rDi adr MW PC J P
        'b0000_0000_0000_0000_0000: ctl = 'b1110_00_000_000_00_00_0_0;  // INSN 0000 = halt

        'b0000_00??_????_????_????: ctl = 'b0000_10_000_000_00_01_0_0;  // INSN 0xxx-3xxx = constant generation
        'b0000_0100_????_????_????: ctl = 'b0001_00_000_001_00_00_0_0;  // INSN 4xxx = load PC relative
        'b0000_0101_????_????_????: ctl = 'b0000_11_001_000_00_01_0_0;  // INSN 5xxx = ALU ops

        'b0000_0111_????_0000_????: ctl = 'b0000_10_111_000_00_01_0_0;  // INSN 7x0x = input
        'b0000_0111_????_0001_????: ctl = 'b0000_00_000_000_00_01_0_1;  // INSN 7x1x = output

        'b0000_1000_????_????_????: ctl = 'b0011_00_000_010_00_00_0_0;  // INSN 8xxx = load byte
        'b0000_1001_????_????_????: ctl = 'b0001_00_000_011_00_00_0_0;  // INSN 9xxx = load word
        'b0000_1010_????_????_????: ctl = 'b0010_00_000_010_01_00_0_0;  // INSN Axxx = store byte
        'b0000_1011_????_????_????: ctl = 'b0010_00_000_011_11_00_0_0;  // INSN Bxxx = store word

        'b0000_1100_????_????_????: ctl = 'b0000_00_000_000_00_01_1_0;  // INSN Cxxx = branch

        'b0001_????_????_????_????: ctl = 'b0000_11_011_000_00_01_0_0;  // STATE 1: commit word -> reg, read next instruction
        'b0010_????_????_????_????: ctl = 'b0000_00_000_000_00_01_0_0;  // STATE 2: write complete, continue to next instruction
        'b0011_????_????_????_????: ctl = 'b0000_11_100_000_00_01_0_0;  // STATE 3: commit byte -> reg, read next instruction

        'b1110_????_????_????_????: ctl = 'b1110_00_000_000_00_00_0_0;  // STATE E: halted
        'b1111_????_????_????_????: ctl = 'b0000_00_000_111_00_00_0_0;  // STATE F: reset

        default:                    ctl = 'b1110_00_000_000_00_00_0_0;  // unknown op/state - panic and halt
    endcase

assign insn_latch_sel = (state != 0);

always @(*) begin
    // next-PC select
    if (sel_jump && cond_true)
        nextpc = pc + 2 + { {6{insn[8]}}, insn[8:0], 1'b0 };
    else
        nextpc = pc + 2;

    // rDi select
    case (sel_rdi)
        'b000: rDi = ccg_out;
        'b001: rDi = alu_out;
        'b010: rDi = pc;
        'b011: rDi = mem_dout;
        'b100: rDi = mem_dout & 16'h00ff;
        'b111: rDi = {8'b0, inport};
        default: rDi = 0;
    endcase

    // Next read select
    case (sel_maddr)
        'b000: mem_addr = nextpc;
        'b001: mem_addr = nextpc + { 7'b0,  insn[7:0], 1'b0 }; // PC relative word offset
        'b010: mem_addr = rS     + { 12'b0,       insn[3:0] }; // bytewise immediate offset
        'b011: mem_addr = rS     + { 11'b0, insn[3:0], 1'b0 }; // wordwise immediate offset
        'b111: mem_addr = 0; // used for reset
        default: mem_addr = 0;
    endcase
end

always @(posedge clk) begin
    if (reset_n == 0) begin
        pc      <= 16'h0000;
        cond    <= 3'b000;
        state   <= 4'b1111;
    end else begin
        state <= next_state;

        case (sel_pc)
            'b00: pc <= pc;
            'b01: pc <= nextpc;
            'b10: pc <= rS;
            'b11: pc <= 'b0;
        endcase

        if (sel_ccw) begin
            cond[2] <= alu_out == 0;    // Z
            cond[1] <= alu_out[15];     // N
            cond[0] <= alu_cout;        // C
        end

        if (sel_outport)
            outport_r <= rD[7:0];

        insn_latch <= insn;
    end
end

assign outport = outport_r;
assign out_pc = pc;
assign out_state = state;
assign out_insn = insn;

endmodule
