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
    // Polyphase FIR Filter with Decimation by 2
    // =========================================================================
    // 
    // Using polyphase decomposition, the filter output y[2n+1] is computed as:
    //   y[2n+1] = P_odd(n) + P_even(n)
    //
    // Where:
    //   P_odd(n)  = h[0]*x_o[n] + h[2]*x_o[n-1] + ... + h[14]*x_o[n-7]
    //   P_even(n) = h[1]*x_e[n] + h[3]*x_e[n-1] + ... + h[15]*x_e[n-7]
    //
    // x_o = odd samples {x[1], x[3], x[5], ...}
    // x_e = even samples {x[0], x[2], x[4], ...}
    // =========================================================================

    // Phase counter: 0 = receiving even sample, 1 = receiving odd sample
    reg phase;
    
    // Shift registers for polyphase decomposition (8 taps each)
    reg signed [7:0] x_odd  [0:7];  // Odd input samples
    reg signed [7:0] x_even [0:7];  // Even input samples
    
    // Clock divider output - enables computation after odd sample captured
    reg clk_div_en;
    
    // Gated clock from ICG for output register
    wire clk_gated;
    
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
    // Clock Divider Enable - generates enable signal at half input rate
    // Enable is high one cycle after odd sample is captured
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_div_en <= 1'b0;
        else
            clk_div_en <= phase;  // High after odd sample captured
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
    // Polyphase Filter Computation (Combinational)
    // P_odd: Even-indexed coefficients (H0,H2,H4,...) with odd samples
    // P_even: Odd-indexed coefficients (H1,H3,H5,...) with even samples
    // -------------------------------------------------------------------------
    wire signed [18:0] p_odd;
    wire signed [18:0] p_even;
    
    assign p_odd = H0  * x_odd[0] + H2  * x_odd[1] + H4  * x_odd[2] + H6  * x_odd[3] +
                   H8  * x_odd[4] + H10 * x_odd[5] + H12 * x_odd[6] + H14 * x_odd[7];
    
    assign p_even = H1  * x_even[0] + H3  * x_even[1] + H5  * x_even[2] + H7  * x_even[3] +
                    H9  * x_even[4] + H11 * x_even[5] + H13 * x_even[6] + H15 * x_even[7];
    
    // -------------------------------------------------------------------------
    // ICG Instance - Clock gating for power efficiency
    // Gated clock only toggles when new output is ready (half input rate)
    // -------------------------------------------------------------------------
    icg u_icg (
        .clk(clk),
        .en(phase),
        .clk_out(clk_gated)
    );
    
    // -------------------------------------------------------------------------
    // Output Register - Clocked by gated clock for power savings
    // Updates at half input rate (decimation by 2)
    // -------------------------------------------------------------------------
    always @(posedge clk_gated or negedge rst_n) begin
        if (!rst_n)
            y_out <= 20'sd0;
        else
            y_out <= p_odd + p_even;
    end

endmodule


// =============================================================================
// ICG (Integrated Clock Gating) Cell
// =============================================================================
// Standard clock gating cell using negative-level-sensitive latch
// followed by AND gate. This prevents clock glitches when enable changes.
//
// Operation:
// - When clk is LOW: latch is transparent, en_latched follows en
// - When clk is HIGH: latch holds previous en value
// - clk_out = clk AND en_latched (glitch-free)
// =============================================================================
module icg (
    input  wire clk,
    input  wire en,
    output wire clk_out
);

    // Latched enable signal
    reg en_latched;
    
    // Negative-level-sensitive latch (transparent when clk is low)
    // This ensures enable is stable before clock rising edge
    always @(*) begin
        if (!clk)
            en_latched = en;
    end
    
    // AND gate for clock gating
    assign clk_out = clk & en_latched;

endmodule
