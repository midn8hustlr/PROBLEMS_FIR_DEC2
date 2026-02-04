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

    // TODO: Implement the area-optimized symmetric FIR filter with decimation by 2
    // Requirements:
    // - Use polyphase decomposition (separate shift registers for odd/even samples)
    // - Exploit coefficient symmetry to pre-add sample pairs before multiplication
    // - Use only 4 multipliers with time-domain multiplexing
    // - See docs/Specification.md for the mathematical derivation

endmodule
