`timescale 1ns/1ps

module fir_filter_dec2 (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire signed [7:0]    x_in,
    output reg  signed [7:0]    y_out   // TODO: determine correct output width
);

    // Symmetric Filter Coefficients: H[k] = H[15-k]
    parameter signed [7:0] H0 = 8'sd2;
    parameter signed [7:0] H1 = 8'sd4;
    parameter signed [7:0] H2 = 8'sd6;
    parameter signed [7:0] H3 = 8'sd10;
    parameter signed [7:0] H4 = 8'sd14;
    parameter signed [7:0] H5 = 8'sd20;
    parameter signed [7:0] H6 = 8'sd26;
    parameter signed [7:0] H7 = 8'sd32;

    // TODO: Implement the symmetric FIR filter with decimation by 2

endmodule
