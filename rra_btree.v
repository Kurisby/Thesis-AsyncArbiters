`timescale 1ns / 1ps

module rra_btree #(
    parameter N           = 4,
    parameter WIDTH       = 2,  // log_2(N)
    parameter NUM_BUFFERS = 0
) (
    input  wire               rstn,

    input  wire [N-1:0]       req,
    output wire [N-1:0]       ack,          

    output wire               root_req,      // request to readout
    output wire [WIDTH-1:0]   data_out,      // winning channel
    input  wire               ack_root       // readout handshake back
);
    
    // interconnection variables
    wire             req_n0, req_n1;
    wire             ack_n0, ack_n1;
    wire [WIDTH-1:0] data_n0, data_n1;
    
    // Ch0/1
    rra_2to1 #(.WIDTH(WIDTH), .NUM_BUFFERS(NUM_BUFFERS)) RRA_01(
        .rstn(rstn),
        .req0 (req[0]), .req1 (req[1]),
        .data0(2'b00),  .data1(2'b01),
        .ack0 (ack[0]), .ack1 (ack[1]),
        .fpa_req (req_n0),
        .data_out(data_n0),
        .ack_fpa (ack_n0)
    );
    
    // Ch2/3
    rra_2to1 #(.WIDTH(WIDTH), .NUM_BUFFERS(NUM_BUFFERS)) RRA_23(
        .rstn(rstn),
        .req0 (req[2]), .req1 (req[3]),
        .data0(2'b10),  .data1(2'b11),
        .ack0 (ack[2]), .ack1 (ack[3]),
        .fpa_req (req_n1),
        .data_out(data_n1),
        .ack_fpa (ack_n1)
    );
    
    // Root
    rra_2to1 #(.WIDTH(WIDTH), .NUM_BUFFERS(1)) RRA_RT(
        .rstn(rstn),
        .req0 (req_n0),  .req1 (req_n1),
        .data0(data_n0), .data1(data_n1),
        .ack0 (ack_n0),  .ack1 (ack_n1),
        .fpa_req (root_req),
        .data_out(data_out),
        .ack_fpa (ack_root)
    );
    
endmodule
