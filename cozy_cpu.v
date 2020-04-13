`default_nettype none

module cozy_cpu (
    input wire clk,
    input wire reset_n,

    output reg [15:0] mem_addr,
    output wire [1:0] mem_bwe,
    output wire [15:0] mem_dout,
    input wire [15:0] mem_din
);

reg [15:0] pc;
reg [15:0] next_pc;

reg [15:0] lr;

reg [2:0] cond;

wire [15:0] alu_out;
wire alu_cout;

reg [15:0] rDi;
wire write_rD;
wire [15:0] rD, rS;

// Latched instruction -- required to make multi-cycle operations work
reg [15:0] insn_latch;
wire insn_latch_sel;
wire [15:0] insn = insn_latch_sel ? insn_latch : mem_din;

wire [15:0] const_out;
wire cond_true;

cozy_constant_generator CCG (
    .insn   (insn),
    .out    (const_out)
);

cozy_condition_evaluator CCE (
    .insn   (insn),
    .cond   (cond),
    .out    (cond_true)
);

cozy_registerfile REG (
    .clk    (clk),
    .rD_sel (insn[11:8]),
    .rD_in  (rDi),
    .rD_we  (write_rD),
    .rD_out (rD),
    .rS_sel (insn[7:4]),
    .rS_out (rS)
);

cozy_alu ALU (
    .rD         (rD),
    .rS         (rS),
    .carry_in   (cond[0]),
    .op         (insn[3:0]),
    .out        (alu_out),
    .carry_out  (alu_cout)
);

reg [2:0] state;
wire [2:0] next_state;
// write_rD defined elsewhere
wire write_cc;
wire [2:0] sel_rdi;
wire [2:0] sel_maddr;
// mem_bwe defined elsewhere
wire [1:0] sel_pc;
wire [2:0] sel_xyz;

reg [17:0] ctl;
assign {next_state, write_rD, write_cc, sel_rdi, sel_maddr, mem_bwe, sel_pc, sel_xyz} = ctl;

always @(*)
    casez ({ state, insn })
        //SSS IIII IIII IIII IIII          SSS Wc rDi adr MW PC XYZ
        'b000_0000_0000_????_????: ctl = 'b110_00_000_000_00_00_000;  // INSN 00xx = halt
        'b000_00??_????_????_????: ctl = 'b000_10_000_000_00_01_000;  // INSN 0xxx-3xxx = constant generation
        'b000_0100_????_????_????: ctl = 'b011_00_000_001_00_00_000;  // INSN 4xxx = load PC relative
        'b000_0101_????_0000_0000: ctl = 'b000_10_010_000_00_01_000;  // INSN 5x00 = mfspr r, pc
        'b000_0101_????_0000_0001: ctl = 'b000_10_011_000_00_01_000;  // INSN 5x01 = mfspr r, lr
        'b000_0101_????_1000_0000: ctl = 'b100_00_000_000_00_11_000;  // INSN 5x80 = mtspr r, pc
        'b000_0101_????_1000_0001: ctl = 'b000_00_000_000_00_01_010;  // INSN 5x80 = mtspr r, lr
        'b000_0110_????_????_????: ctl = 'b000_11_001_000_00_01_000;  // INSN 6xxx = ALU ops
        'b000_0111_????_????_????: ctl = 'b000_01_001_000_00_01_000;  // INSN 7xxx = CMP ops
        'b000_1000_????_????_????: ctl = 'b010_00_000_010_00_00_000;  // INSN 8xxx = load byte
        'b000_1001_????_????_????: ctl = 'b011_00_000_011_00_00_000;  // INSN 9xxx = load word
        'b000_1010_????_????_????: ctl = 'b001_00_000_010_01_00_000;  // INSN Axxx = store byte
        'b000_1011_????_????_????: ctl = 'b001_00_000_011_11_00_000;  // INSN Bxxx = store word
        'b000_1100_????_????_????: ctl = 'b100_00_000_000_00_10_000;  // INSN Cxxx = branch
        'b000_1101_????_????_????: ctl = 'b100_00_000_000_00_10_001;  // INSN Dxxx = branch+link
        //000_1110_????_????_????: ctl = 'b                        ;  // INSN Exxx = unused
        //000_1111_????_????_????: ctl = 'b                        ;  // INSN Fxxx = unused
        'b001_????_????_????_????: ctl = 'b000_00_000_000_00_01_000;  // STATE 1: write complete, continue to next instruction
        'b010_????_????_????_????: ctl = 'b000_11_101_000_00_01_000;  // STATE 2: commit byte -> reg, read next instruction
        'b011_????_????_????_????: ctl = 'b000_11_100_000_00_01_000;  // STATE 3: commit word -> reg, read next instruction
        'b100_????_????_????_????: ctl = 'b000_00_000_000_00_01_000;  // STATE 4: branch delay hack
        //101_????_????_????_????: ctl = 'b???_??_???_???_??_??_???;  // STATE 5: unused
        'b110_????_????_????_????: ctl = 'b110_00_000_000_00_00_000;  // STATE 6: halted
        'b111_????_????_????_????: ctl = 'b000_00_000_111_00_00_000;  // STATE 7: reset
        default:                   ctl = 'b110_00_000_000_00_00_000;  // unknown op/state - panic and halt
    endcase

assign insn_latch_sel = (state != 0);

always @(*) begin
    case (sel_pc)
        'b00: next_pc = pc;
        'b01: next_pc = pc + 16'h2;
        'b10: next_pc = pc + (cond_true ? { {6{insn[8]}}, insn[8:0], 1'b0 } : 16'h0);
        'b11: next_pc = rD & 16'hfffe;
    endcase

    // rDi select
    case (sel_rdi)
        'b000: rDi = const_out;
        'b001: rDi = alu_out;
        'b010: rDi = pc;
        'b011: rDi = lr;
        'b100: rDi = mem_din;
        'b101: rDi = mem_din & 16'h00ff;
        default: rDi = 0;
    endcase

    // Memory read select
    case (sel_maddr)
        'b000: mem_addr = pc + 16'h2;
        'b001: mem_addr = pc + 16'h2 + { 7'b0,  insn[7:0], 1'b0 }; // PC relative word offset
        'b010: mem_addr = rS         + { 12'b0,       insn[3:0] }; // bytewise immediate offset
        'b011: mem_addr = rS         + { 11'b0, insn[3:0], 1'b0 }; // wordwise immediate offset
        'b111: mem_addr = 0; // used for reset
        default: mem_addr = 0;
    endcase
end

always @(posedge clk) begin
    if (reset_n == 0) begin
        pc      <= 'h0;
        cond    <= 'b0;
        state   <= 'b111;
    end else begin
        state <= next_state;
        pc <= next_pc;

        if (write_cc) begin
            cond[2] <= alu_out == 0;    // Z
            cond[1] <= alu_out[15];     // N
            cond[0] <= alu_cout;        // C
        end

        case (sel_xyz)
            'b001: lr <= pc;
            'b010: lr <= rD;
            default: ; /* nothing */
        endcase

        insn_latch <= insn;
    end
end

assign mem_dout = rD;

endmodule
