integer _test_count  = 0;
integer _test_fail = 0;

`define OK(chk) begin \
    _test_count = _test_count + 1; \
    if (chk) begin \
        $display("ok %0d # L=%0d T=%0d", _test_count, `__LINE__, $time); \
    end else begin \
        $display("not ok %0d # L%0d T%0d", `__LINE__, $time); \
        _test_fail = _test_fail + 1; \
    end \
end

`define IS(sig, val) begin \
    _test_count = _test_count + 1; \
    if (sig == val) begin \
        $display("ok %0d # L%0d T%0d", _test_count, `__LINE__, $time); \
    end else begin \
        $display("not ok %0d # L%0d T%0d, got %0x while expecting %0x", _test_count, `__LINE__, $time, sig, val); \
        _test_fail = _test_fail + 1; \
    end \
end

`define NOTE(msg) begin \
    $display("# %s", msg); \
end

`define DONE_TESTING begin \
    $display("1..%0d", _test_count); \
    if (_test_fail == 0) \
        $display("# SUCCESS! Tests passed: %0d", _test_count); \
    else \
        $display("# FAILURE! Tests failed: %0d", _test_fail); \
    $finish; \
end

`define CLOCK(signal, period) \
    reg signal = 0; \
    always #(period/2.0) if (glbl.GSR == 0) signal = !signal;

`define TIMEOUT(timeout) \
    initial begin \
        #timeout $display("Bail out! Timeout reached"); \
        $finish; \
    end

// Wait for GSR to be deasserted. This is required for many Xilinx primitive
// simulations to work correctly.
`define WAIT_GSR \
    #1; @(negedge glbl.GSR or !glbl.GSR); #0;
