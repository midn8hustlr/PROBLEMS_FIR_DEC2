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

    // TODO: Implement the area-efficient polyphase FIR filter with decimation by 2
    // using time-domain multiplexing (8 shared multipliers instead of 16)

endmodule
