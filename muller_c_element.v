`timescale 1ns / 1ps

module muller_c_element(
    input  rstn,
    input  A, B,
    output Y
    );
    
(* dont_touch = "true" *) wire C;

// Note: #0.1 only works in SIM
assign #0.1 C = rstn & ((A & B) | (C & (A | B)));
assign Y = C;
    
endmodule
