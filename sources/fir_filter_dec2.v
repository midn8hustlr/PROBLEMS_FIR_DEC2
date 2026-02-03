`timescale 1ns/1ps

module fir_filter_dec2 (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire signed [7:0]    x_in,
    output reg  signed [19:0]   y_out
);

    // Filter Coefficients (directly as parameters for clarity)
    parameter signed [7:0] H0  = 8'sd2;
    parameter signed [7:0] H1  = 8'sd4;
    parameter signed [7:0] H2  = 8'sd6;
    parameter signed [7:0] H3  = 8'sd10;
    parameter signed [7:0] H4  = 8'sd14;
    parameter signed [7:0] H5  = 8'sd20;
    parameter signed [7:0] H6  = 8'sd26;
    parameter signed [7:0] H7  = 8'sd32;
    parameter signed [7:0] H8  = 8'sd26;
    parameter signed [7:0] H9  = 8'sd32;
    parameter signed [7:0] H10 = 8'sd14;
    parameter signed [7:0] H11 = 8'sd20;
    parameter signed [7:0] H12 = 8'sd6;
    parameter signed [7:0] H13 = 8'sd10;
    parameter signed [7:0] H14 = 8'sd2;
    parameter signed [7:0] H15 = 8'sd4;

    // =========================================================================
    // Area-Efficient Polyphase FIR Filter with Decimation by 2
    // Using Time-Domain Multiplexing
    // =========================================================================
    // 
    // The filter output y[2n+1] is computed as:
    //   y[2n+1] = P_odd(n) + P_even(n)
    //
    // Time-domain multiplexing reuses 8 multipliers:
    //   Phase 0 (even input): Compute P_even with odd coefficients (H1,H3,...)
    //   Phase 1 (odd input):  Compute P_odd with even coefficients (H0,H2,...)
    //
    // This saves 8 multipliers compared to parallel implementation.
    // =========================================================================

    // Phase counter: 0 = receiving even sample, 1 = receiving odd sample
    reg phase;
    
    // Shift registers for polyphase decomposition (8 taps each)
    reg signed [7:0] x_odd  [0:7];  // Odd input samples
    reg signed [7:0] x_even [0:7];  // Even input samples
    
    // Registered partial sum from phase 0 (P_even)
    reg signed [18:0] p_even_reg;
    
    // -------------------------------------------------------------------------
    // Phase Counter - alternates between 0 (even) and 1 (odd)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase <= 1'b0;
        else
            phase <= ~phase;
    end
    
    // -------------------------------------------------------------------------
    // Sample Capture - Polyphase input demultiplexing
    // Even samples go to x_even shift register
    // Odd samples go to x_odd shift register
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
                // Phase 0: Capture even sample, shift even register
                for (i = 7; i > 0; i = i - 1)
                    x_even[i] <= x_even[i-1];
                x_even[0] <= x_in;
            end else begin
                // Phase 1: Capture odd sample, shift odd register
                for (i = 7; i > 0; i = i - 1)
                    x_odd[i] <= x_odd[i-1];
                x_odd[0] <= x_in;
            end
        end
    end
    
    // -------------------------------------------------------------------------
    // Multiplexed Coefficient Selection
    // Phase 0: Use odd-indexed coefficients (H1, H3, H5, ...)
    // Phase 1: Use even-indexed coefficients (H0, H2, H4, ...)
    // -------------------------------------------------------------------------
    wire signed [7:0] coef0, coef1, coef2, coef3, coef4, coef5, coef6, coef7;
    
    assign coef0 = phase ? H0  : H1;
    assign coef1 = phase ? H2  : H3;
    assign coef2 = phase ? H4  : H5;
    assign coef3 = phase ? H6  : H7;
    assign coef4 = phase ? H8  : H9;
    assign coef5 = phase ? H10 : H11;
    assign coef6 = phase ? H12 : H13;
    assign coef7 = phase ? H14 : H15;
    
    // -------------------------------------------------------------------------
    // Multiplexed Sample Selection
    // Phase 0: Use even samples for P_even computation
    // Phase 1: Use odd samples for P_odd computation
    // -------------------------------------------------------------------------
    wire signed [7:0] samp0, samp1, samp2, samp3, samp4, samp5, samp6, samp7;
    
    assign samp0 = phase ? x_odd[0] : x_even[0];
    assign samp1 = phase ? x_odd[1] : x_even[1];
    assign samp2 = phase ? x_odd[2] : x_even[2];
    assign samp3 = phase ? x_odd[3] : x_even[3];
    assign samp4 = phase ? x_odd[4] : x_even[4];
    assign samp5 = phase ? x_odd[5] : x_even[5];
    assign samp6 = phase ? x_odd[6] : x_even[6];
    assign samp7 = phase ? x_odd[7] : x_even[7];
    
    // -------------------------------------------------------------------------
    // 8 Shared Multipliers (Time-Domain Multiplexed)
    // These compute P_even in phase 0 and P_odd in phase 1
    // -------------------------------------------------------------------------
    wire signed [15:0] prod0, prod1, prod2, prod3, prod4, prod5, prod6, prod7;
    
    assign prod0 = coef0 * samp0;
    assign prod1 = coef1 * samp1;
    assign prod2 = coef2 * samp2;
    assign prod3 = coef3 * samp3;
    assign prod4 = coef4 * samp4;
    assign prod5 = coef5 * samp5;
    assign prod6 = coef6 * samp6;
    assign prod7 = coef7 * samp7;
    
    // -------------------------------------------------------------------------
    // Partial Sum Computation (sum of 8 products)
    // -------------------------------------------------------------------------
    wire signed [18:0] partial_sum;
    
    assign partial_sum = prod0 + prod1 + prod2 + prod3 + 
                         prod4 + prod5 + prod6 + prod7;
    
    // -------------------------------------------------------------------------
    // P_even Register - Store partial sum from phase 0
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            p_even_reg <= 19'sd0;
        else if (!phase)
            p_even_reg <= partial_sum;  // Capture P_even at end of phase 0
    end
    
    // -------------------------------------------------------------------------
    // Output Register - Compute final sum at end of phase 1
    // y_out = P_even (registered) + P_odd (current partial_sum)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            y_out <= 20'sd0;
        else if (phase)
            y_out <= p_even_reg + partial_sum;  // P_even + P_odd
    end

endmodule
