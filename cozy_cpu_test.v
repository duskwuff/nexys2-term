`default_nettype none

module cozy_cpu_test ();

`include "testbench-helpers.v"

`CLOCK(clk, 1);
`TIMEOUT(10000);

reg nrst;

wire [1:0] bwe;
wire [15:0] addr, drd, dwr;

cozy_cpu UUT (
    .clk        (clk),
    .reset_n    (nrst),

    .mem_addr   (addr),
    .mem_bwe    (bwe),
    .mem_dout   (dwr),
    .mem_din    (drd)
);

cozy_memory #(
    .BITS (8)
) MEM (
    .clk        (clk),
    .addr       (addr),
    .bwe        (bwe),
    .din        (dwr),
    .dout       (drd)
);

integer prog_pc = 0;
integer i;
integer test_line;

initial begin

`define NEW_TEST begin \
    test_line = `__LINE__; \
    prog_pc = 0; \
    UUT.pc = 'bx; UUT.state = 'bx; UUT.cond = 'bx; \
    for (i = 1; i <= 15; i = i + 1) UUT.REG.R[i] = 16'bxxxx; \
    for (i = 0; i < 256; i = i + 2) begin MEM.ram_hi[i/2] = 8'bxx; MEM.ram_lo[i/2] = 8'bxx; end \
end
`define MEM_SET(addr, val) {MEM.ram_hi[(addr)/2], MEM.ram_lo[(addr)/2]} <= val;
`define PROGRAM(word) `MEM_SET(prog_pc, word); prog_pc = prog_pc + 2;
`define PULSE_RESET nrst = 0; #1; nrst = 1; #1;
`define WAIT_FOR_HALT @(UUT.state == 'b110); #0.5;
`define MEM_IS(addr, val) `IS({MEM.ram_hi[(addr)/2], MEM.ram_lo[(addr)/2]}, (val));

`WAIT_GSR;

`NOTE("Reset and constant loading");
    `NEW_TEST;
    `PROGRAM(16'h0112); // 00: load r1, #0012
    `PROGRAM(16'h0223); // 02: load r2, #0023
    `PROGRAM(16'h0f34); // 04: load r15, #0034
    `PROGRAM(16'h1145); // 06: load r1, #ff45
    `PROGRAM(16'h2156); // 08: load r1, #5600
    `PROGRAM(16'h3167); // 0a: load r1, #67ff
    `PROGRAM(16'h0000); // 0c: halt

    `PULSE_RESET;
    `IS(UUT.pc, 16'h0000);
    `IS(UUT.state, 0);

    #1; `IS(UUT.pc, 16'h0002); `IS(UUT.REG.r1,  16'h0012);
    #1; `IS(UUT.pc, 16'h0004); `IS(UUT.REG.r2,  16'h0023);
    #1; `IS(UUT.pc, 16'h0006); `IS(UUT.REG.r15, 16'h0034);
    #1; `IS(UUT.pc, 16'h0008); `IS(UUT.REG.r1,  16'hff45);
    #1; `IS(UUT.pc, 16'h000a); `IS(UUT.REG.r1,  16'h5600);
    #1; `IS(UUT.pc, 16'h000c); `IS(UUT.REG.r1,  16'h67ff);
    #1; `IS(UUT.pc, 16'h000c); `IS(UUT.state, 4'b110); // halted
    #1; `IS(UUT.pc, 16'h000c); `IS(UUT.state, 4'b110); // still halted


`NOTE("Load PC-relative test");
    `NEW_TEST;
    `PROGRAM(16'h0101); // 00: load r1, #0001
    `PROGRAM(16'h4103); // 02: loadimm r1, *0a
    `PROGRAM(16'h4200); // 04: loadimm r2, *06 (next insn!)
    `PROGRAM(16'h4303); // 06: loadimm r3, *0e
    `PROGRAM(16'hff08); // 08
    `PROGRAM(16'h1234); // 0a - read target
    `PROGRAM(16'h0d0c); // 0c
    `PROGRAM(16'h5678); // 0e

    `PULSE_RESET;
    #7;
    `IS(UUT.REG.r1, 16'h1234);
    `IS(UUT.REG.r2, 16'h4303);
    `IS(UUT.REG.r3, 16'h5678);


`NOTE("ALU test");
    `NEW_TEST;
    `PROGRAM(16'h0112); // load r1, #0012
    `PROGRAM(16'h0234); // load r2, #0034
    `PROGRAM(16'h6320); // mov r3, r2
    `PROGRAM(16'h6128); // add r1, r2
    `PROGRAM(16'h712c); // cmp r1, r2
    `PROGRAM(16'h721c); // cmp r2, r1
    `PROGRAM(16'h722c); // cmp r2, r2
    `PROGRAM(16'h6223); // xor r2, r2
    `PROGRAM(16'h6217); // not r2, r1
    `PROGRAM(16'h621e); // neg r2, r1
    `PROGRAM(16'h621a); // inc r2, r1
    `PROGRAM(16'h621b); // dec r2, r1
    `PROGRAM(16'h620a); // inc r2, r0
    `PROGRAM(16'h620b); // dec r2, r0
    `PROGRAM(16'h600a); // clc (inc r0, r0)
    `PROGRAM(16'h600b); // sec (dec r0, r0)
    `PROGRAM(16'h6214); // shr r2, r1
    `PROGRAM(16'h6224); // shr r2, r2
    `PROGRAM(16'h6215); // shrc r2, r1
    `PROGRAM(16'h6225); // shrc r2, r2
    `PROGRAM(16'h6228); // shl r2, r2   ; actually add -- reuse r2 because I need a high bit
    `PROGRAM(16'h600b); // sec
    `PROGRAM(16'h6229); // shlc r2, r2  ; actually adc
    `PROGRAM(16'h0000); // halt

    `PULSE_RESET;
    #1; `IS(UUT.REG.r1, 16'h0012);
    #1; `IS(UUT.REG.r2, 16'h0034);
    #1; `IS(UUT.REG.r3, 16'h0034); `IS(UUT.cond, 3'b000);
    #1; `IS(UUT.REG.r1, 16'h0046); `IS(UUT.cond, 3'b000); // add: 0012 + 0034 = 0046 znc
    #1; `IS(UUT.REG.r1, 16'h0046); `IS(UUT.cond, 3'b000); // cmp: 0046 - 0012 = 0011 znc
    #1; `IS(UUT.REG.r2, 16'h0034); `IS(UUT.cond, 3'b011); // cmp: 0012 - 0034 = ffde zNC
    #1; `IS(UUT.REG.r2, 16'h0034); `IS(UUT.cond, 3'b100); // cmp: 0034 - 0034 = 0000 Znc
    #1; `IS(UUT.REG.r2, 16'h0000); `IS(UUT.cond, 3'b100); // xor: 0034 ^ 0034 = 0000 Znc
    #1; `IS(UUT.REG.r2, 16'hffb9); `IS(UUT.cond, 3'b010); // not: ~0046  = ffb9 zNc
    #1; `IS(UUT.REG.r2, 16'hffba); `IS(UUT.cond, 3'b011); // neg: -0046  = ffba zNC
    #1; `IS(UUT.REG.r2, 16'h0047); `IS(UUT.cond, 3'b000); // inc: 0046++ = 0047 znc
    #1; `IS(UUT.REG.r2, 16'h0045); `IS(UUT.cond, 3'b000); // dec: 0046-- = 0045 znc
    #1; `IS(UUT.REG.r2, 16'h0001); `IS(UUT.cond, 3'b000); // inc: 0000++ = 0001 znc
    #1; `IS(UUT.REG.r2, 16'hffff); `IS(UUT.cond, 3'b011); // dec: 0000-- = ffff zNC
    #1;                            `IS(UUT.cond, 3'b000); // inc: 0++    = znc (bootleg clc)
    #1;                            `IS(UUT.cond, 3'b011); // dec: 0--    = zNC (bootleg sec)
    #1; `IS(UUT.REG.r2, 16'h0023); `IS(UUT.cond, 3'b000); // shr: 0046>> = 0023/0 znc
    #1; `IS(UUT.REG.r2, 16'h0011); `IS(UUT.cond, 3'b001); // shr: 0023>> = 0011/1 znC
    #1; `IS(UUT.REG.r2, 16'h8023); `IS(UUT.cond, 3'b010); // src: >>0046 = 8023/0 zNc
    #1; `IS(UUT.REG.r2, 16'h4011); `IS(UUT.cond, 3'b001); // src: >>0046 = 4011/1 znC
    #1; `IS(UUT.REG.r2, 16'h8022); `IS(UUT.cond, 3'b010); // shl: <<4011 = 0/8022 zNc
    #1;                            `IS(UUT.cond, 3'b011); // sec:                 zNC
    #1; `IS(UUT.REG.r2, 16'h0045); `IS(UUT.cond, 3'b001); // slc: 8022<< = 1/0045 znC
    #1; `IS(UUT.state, 'b110);


`NOTE("Store byte/word test");
    `NEW_TEST;
    `PROGRAM(16'h0141); // 00: load r1, #0041
    `PROGRAM(16'h4208); // 02: load r2, *12 (#1234)
    `PROGRAM(16'h4308); // 02: load r3, *14 (#5678)
    `PROGRAM(16'ha210); // 04: sb r2, r1(0)
    `PROGRAM(16'ha313); // 06: sb r3, r1(3)
    `PROGRAM(16'h0180); // 08: load r1, #0080
    `PROGRAM(16'hb210); // 0a: sw r2, r1(0)
    `PROGRAM(16'hb312); // 0c: sw r3, r1(4)
    `PROGRAM(16'h04a5); // 0e: load r4, #00a5
    `PROGRAM(16'h0000); // 10: halt
    `PROGRAM(16'h1234); // 12
    `PROGRAM(16'h5678); // 14
    `MEM_SET(16'h0040, 16'h0000);
    `MEM_SET(16'h0042, 16'h0000);
    `MEM_SET(16'h0044, 16'h0000);

    `PULSE_RESET; `WAIT_FOR_HALT;
    `IS(UUT.REG.r1, 16'h0080);
    `IS(UUT.REG.r2, 16'h1234);
    `IS(UUT.REG.r3, 16'h5678);
    `IS(UUT.REG.r4, 16'h00a5);

    `MEM_IS(16'h0040, 16'h3400);
    `MEM_IS(16'h0042, 16'h0000);
    `MEM_IS(16'h0044, 16'h0078);

    `MEM_IS(16'h0080, 16'h1234);
    `MEM_IS(16'h0084, 16'h5678);


`NOTE("Load byte/word test");
    `NEW_TEST;
    `PROGRAM(16'h0111); // 00: load r1, #0011
    `PROGRAM(16'h8210); // 02: lb r2, r1(0)
    `PROGRAM(16'h8311); // 04: lb r3, r1(1)
    `PROGRAM(16'h8412); // 06: lb r4, r1(2)
    `PROGRAM(16'h0110); // 08: load r1, #0010
    `PROGRAM(16'h9810); // 0a: lw r8, r1(0)
    `PROGRAM(16'h9911); // 0c: lw r9, r1(2)
    `PROGRAM(16'h0000); // 0e: halt
    `PROGRAM(16'h1234); // 10
    `PROGRAM(16'h5678); // 12

    `PULSE_RESET; `WAIT_FOR_HALT;
    `IS(UUT.REG.r2, 16'h0012);
    `IS(UUT.REG.r3, 16'h0078);
    `IS(UUT.REG.r4, 16'h0056);
    `IS(UUT.REG.r8, 16'h1234);
    `IS(UUT.REG.r9, 16'h5678);


`NOTE("Branching test");
    `NEW_TEST;
    `PROGRAM(16'h600a); // 00: inc r0, r0 (clears condition bits)
    `PROGRAM(16'hc07f); // 02: beq YEET
    `PROGRAM(16'hc205); // 04: bne *+a (0010)
    `PROGRAM(16'hxxxx); // 06: halt (skipped)
    `PROGRAM(16'hce00); // 08: bra *+0 (000a)
    `PROGRAM(16'hxxxx); // 0a: (skipped)
    `PROGRAM(16'hxxxx); // 0c: (skipped)
    `PROGRAM(16'hxxxx); // 0e: (skipped)
    `PROGRAM(16'hcffb); // 10: bra *-8 (0008)

    `PULSE_RESET;
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0002); `IS(UUT.cond, 3'b000); // initial conditions
    #1; `IS(UUT.state, 3'b100);
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0004); // didn't jump
    #1; `IS(UUT.state, 3'b100);
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0010); // did jump
    #1; `IS(UUT.state, 3'b100);
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0008); // did jump again
    #1; `IS(UUT.state, 3'b100);
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h000a); // did +0


`NOTE("Link register tests");
    `NEW_TEST;
    `PROGRAM(16'h010e); // 00: li r1, 0010
    `PROGRAM(16'hde02); // 02: bl *+4 (0008)
    `PROGRAM(16'h0000); // 04: (return target)
    `PROGRAM(16'hxxxx); // 06: ---
    `PROGRAM(16'h5200); // 08: mfspr r2, pc
    `PROGRAM(16'h5301); // 0a: mfspr r3, lr
    `PROGRAM(16'h5180); // 0c: mtspr r1, pc (jmp r1 = 0010)
    `PROGRAM(16'hxxxx); // 0e: ---
    `PROGRAM(16'h5181); // 10: mtspr r2, lr


    `PULSE_RESET;
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0002); `IS(UUT.REG.r1, 16'h000e);   // li r1
    #1; `IS(UUT.state, 3'b100);
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0008); `IS(UUT.lr, 16'h0004);       // bl
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h000a); `IS(UUT.REG.r2, 16'h0008);   // mfspr r2, pc
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h000c); `IS(UUT.REG.r3, 16'h0004);   // mfspr r3, lr
    #1; `IS(UUT.state, 3'b100);
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0010);                              // mtspr r1, pc - jumped to 0010
    #1; `IS(UUT.state, 3'b000); `IS(UUT.pc, 16'h0012); `IS(UUT.lr, 16'h000e);       // mtspr r1, lr

`DONE_TESTING;

end

endmodule
