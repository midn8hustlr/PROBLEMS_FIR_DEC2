`timescale 1ns/1ps

module fir_filter_dec2 (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire signed [7:0]    x_in,
    output reg  signed [19:0]   y_out
);

    // =========================================================================
    // Symmetric Filter Coefficients
    // H[k] = H[15-k], so only 8 unique values needed
    // =========================================================================
    parameter signed [7:0] H0 = 8'sd2;   // H0 = H15
    parameter signed [7:0] H1 = 8'sd4;   // H1 = H14
    parameter signed [7:0] H2 = 8'sd6;   // H2 = H13
    parameter signed [7:0] H3 = 8'sd10;  // H3 = H12
    parameter signed [7:0] H4 = 8'sd14;  // H4 = H11
    parameter signed [7:0] H5 = 8'sd20;  // H5 = H10
    parameter signed [7:0] H6 = 8'sd26;  // H6 = H9
    parameter signed [7:0] H7 = 8'sd32;  // H7 = H8

    // =========================================================================
    // Area-Optimized Symmetric FIR Filter with Decimation by 2
    // =========================================================================
    //
    // Architecture:
    // 1. Polyphase decomposition: separate shift registers for odd/even samples
    // 2. Symmetric pre-addition: add sample pairs before multiplication
    // 3. Time-domain multiplexing: 4 multipliers compute 8 products over 2 phases
    //
    // For y[2n+1]:
    //   Phase 0: Compute h[0]*(x_o[n]+x_e[n-7]) + h[2]*(...) + h[4]*(...) + h[6]*(...)
    //   Phase 1: Compute h[1]*(x_e[n]+x_o[n-7]) + h[3]*(...) + h[5]*(...) + h[7]*(...)
    //   Output:  Sum of both phases
    // =========================================================================

    // Phase counter: 0 = even sample input, 1 = odd sample input
    reg phase;

    // Polyphase shift registers (8 taps each)
    reg signed [7:0] x_odd  [0:7];  // Odd input samples: x_o[n-1], x_o[n-2], ...
    reg signed [7:0] x_even [0:7];  // Even input samples: x_e[n], x_e[n-1], ...

    // Registered symmetric pre-sums (captured at end of phase 1)
    reg signed [8:0] sym_sum [0:7];

    // Partial sum accumulator
    reg signed [18:0] partial_sum;

    // -------------------------------------------------------------------------
    // Phase Counter
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase <= 1'b0;
        else
            phase <= ~phase;
    end

    // -------------------------------------------------------------------------
    // Polyphase Sample Capture
    // Even samples captured during phase 0, odd samples during phase 1
    // -------------------------------------------------------------------------
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                x_odd[i]  <= 8'sd0;
                x_even[i] <= 8'sd0;
            end
        end else begin
            if (!phase) begin
                // Phase 0: Capture even sample
                for (i = 7; i > 0; i = i - 1)
                    x_even[i] <= x_even[i-1];
                x_even[0] <= x_in;
            end else begin
                // Phase 1: Capture odd sample
                for (i = 7; i > 0; i = i - 1)
                    x_odd[i] <= x_odd[i-1];
                x_odd[0] <= x_in;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Symmetric Pre-Sum Computation
    // Captured at end of phase 1 when all samples for y[2n+1] are available
    //
    // At end of phase 1 (before clock edge):
    //   x_in = x_o[n] (current odd input, not yet in shift register)
    //   x_odd[k] = x_o[n-1-k] for k=0..7
    //   x_even[k] = x_e[n-k] for k=0..7
    //
    // Symmetric pairs for y[2n+1]:
    //   sym_sum[0] = x_o[n] + x_e[n-7]     → coefficient H0
    //   sym_sum[1] = x_e[n] + x_o[n-7]     → coefficient H1
    //   sym_sum[2] = x_o[n-1] + x_e[n-6]   → coefficient H2
    //   sym_sum[3] = x_e[n-1] + x_o[n-6]   → coefficient H3
    //   sym_sum[4] = x_o[n-2] + x_e[n-5]   → coefficient H4
    //   sym_sum[5] = x_e[n-2] + x_o[n-5]   → coefficient H5
    //   sym_sum[6] = x_o[n-3] + x_e[n-4]   → coefficient H6
    //   sym_sum[7] = x_e[n-3] + x_o[n-4]   → coefficient H7
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1)
                sym_sum[i] <= 9'sd0;
        end else if (phase) begin
            // Capture symmetric sums at end of phase 1
            // Note: x_in has x_o[n], x_odd[k] has x_o[n-1-k], x_even[k] has x_e[n-k]
            sym_sum[0] <= x_in + x_even[7];      // x_o[n] + x_e[n-7]
            sym_sum[1] <= x_even[0] + x_odd[6];  // x_e[n] + x_o[n-7]
            sym_sum[2] <= x_odd[0] + x_even[6];  // x_o[n-1] + x_e[n-6]
            sym_sum[3] <= x_even[1] + x_odd[5];  // x_e[n-1] + x_o[n-6]
            sym_sum[4] <= x_odd[1] + x_even[5];  // x_o[n-2] + x_e[n-5]
            sym_sum[5] <= x_even[2] + x_odd[4];  // x_e[n-2] + x_o[n-5]
            sym_sum[6] <= x_odd[2] + x_even[4];  // x_o[n-3] + x_e[n-4]
            sym_sum[7] <= x_even[3] + x_odd[3];  // x_e[n-3] + x_o[n-4]
        end
    end

    // -------------------------------------------------------------------------
    // Coefficient and Sample Multiplexing for 4 Shared Multipliers
    // Phase 0: Use H0, H2, H4, H6 with sym_sum[0,2,4,6]
    // Phase 1: Use H1, H3, H5, H7 with sym_sum[1,3,5,7]
    // -------------------------------------------------------------------------
    wire signed [7:0] coef0, coef1, coef2, coef3;
    wire signed [8:0] samp0, samp1, samp2, samp3;

    assign coef0 = phase ? H1 : H0;
    assign coef1 = phase ? H3 : H2;
    assign coef2 = phase ? H5 : H4;
    assign coef3 = phase ? H7 : H6;

    assign samp0 = phase ? sym_sum[1] : sym_sum[0];
    assign samp1 = phase ? sym_sum[3] : sym_sum[2];
    assign samp2 = phase ? sym_sum[5] : sym_sum[4];
    assign samp3 = phase ? sym_sum[7] : sym_sum[6];

    // -------------------------------------------------------------------------
    // 4 Shared Multipliers (8-bit coef × 9-bit sum = 17-bit product)
    // -------------------------------------------------------------------------
    wire signed [16:0] prod0, prod1, prod2, prod3;

    assign prod0 = coef0 * samp0;
    assign prod1 = coef1 * samp1;
    assign prod2 = coef2 * samp2;
    assign prod3 = coef3 * samp3;

    // -------------------------------------------------------------------------
    // Sum of 4 Products
    // -------------------------------------------------------------------------
    wire signed [18:0] four_sum;

    assign four_sum = prod0 + prod1 + prod2 + prod3;

    // -------------------------------------------------------------------------
    // Accumulation and Output
    // Phase 0: Store partial sum (4 products)
    // Phase 1: Output complete sum (8 products total)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partial_sum <= 19'sd0;
            y_out <= 20'sd0;
        end else begin
            if (!phase) begin
                // End of phase 0: store first 4 products
                partial_sum <= four_sum;
            end else begin
                // End of phase 1: output sum of all 8 products
                y_out <= partial_sum + four_sum;
            end
        end
    end

endmodule
