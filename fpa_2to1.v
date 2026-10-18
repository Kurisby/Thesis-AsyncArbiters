`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/31/2026 12:35:09 AM
// Design Name: 
// Module Name: fpa_2to1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fpa_2to1 #(
    parameter WIDTH       = 1,      // width of the data bus (default = 1)
    parameter NUM_BUFFERS = 0
) (
    input  wire              rstn,    // Active LOW from USER

    // downstream face (toward detectors / child cells)
    input  wire              req0,    // ch0
    input  wire              req1,    // ch1
    input  wire [WIDTH-1:0]  data0,   // ch0 data bus
    input  wire [WIDTH-1:0]  data1,   // ch1 data bus
    output wire              ack0,    // active LOW
    output wire              ack1,    // active LOW

    // upstream face (toward readout / parent cell)
    output wire              fpa_req,
    output wire [WIDTH-1:0]  data_out,
    input  wire              ack_fpa  // active LOW
);

    (* dont_touch = "true" *) wire r0_in, r1_in;
    (* dont_touch = "true" *) wire a0, a1;
    
    // priority network
    wire r0 = rstn & req0; //(rstn & req0 & ~req1) | (rstn & req0 & req1);   // ch0 HIGH OR ch0/ch1 collision
    wire r1 = rstn & ~req0 & req1;                            // ch0 LOW AND ch1 HIGH
    
    // async latch
    assign r0_in = r0 & ~a1;
    assign r1_in = r1 & ~a0;
    muller_c_element c0 (.rstn(rstn), .A(r0_in), .B(ack_fpa), .Y(a0));
    muller_c_element c1 (.rstn(rstn), .A(r1_in), .B(ack_fpa), .Y(a1));
    assign ack0 = ~a0;
    assign ack1 = ~a1;
    
    wire pre_fpa_req = a0 | a1;
    buffer #(.NUM_BUFFERS(NUM_BUFFERS)) fpa_buffer (.in(pre_fpa_req), .out(fpa_req));
    
    // data bus (origin select)
    (* dont_touch = "true" *) wire [WIDTH-1:0] data = (a1) ? data1 : data0;  
    data_latch #(.WIDTH(WIDTH)) d_latch (
        .rstn(rstn),             // reset
        .req(fpa_req), .D(data), // D-Latch inputs
        .Q(data_out)             // D-Latch output
    );

endmodule
