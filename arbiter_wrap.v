`timescale 1ns/1ps

`include "config.vh"

module arbiter_wrap #(
    parameter N           = `N_CHANNELS,
    parameter WIDTH       = (`N_CHANNELS <= 2) ? 1 : $clog2(`N_CHANNELS),
    parameter NUM_BUFFERS = 4
) (
    input  wire             resetn,
    input  wire [N-1:0]     req,          // from N photon or generated signals
    output wire [N-1:0]     ack,          // ACTIVE HIGH to apd_req_latch
    output wire             grant,        // single serialized grant to readout
    output wire [WIDTH-1:0] origin,       // which channel won
    input  wire             grant_ack     // ACTIVE HIGH from grant_sink
`ifdef BothTrees
   ,output wire             grant_b,      // RRA cell's serialized grant, FPA cell's serialized above
    output wire [WIDTH-1:0] origin_b,
    input  wire             grant_ack_b
`endif
);

wire [N-1:0] ack_n;
wire         grant_ack_n = ~grant_ack;

`ifdef NoArbiter
    assign ack_n = {N{1'b1}};   // unused
    no_arbiter #(.N(N), .WIDTH(WIDTH)) arb (
        .resetn(resetn), .req(req), .ack(ack),
        .grant(grant), .origin(origin), .grant_ack(grant_ack)
    );
`elsif FPACell
    assign ack = ~ack_n;
    generate
        if (N != 2) begin : g_d1_requires_two_channels
            d1_requires_N_CHANNELS_eq_2 u_elab_error();
        end
    endgenerate
    fpa_2to1 #(.WIDTH(WIDTH), .NUM_BUFFERS(NUM_BUFFERS)) arb (
        .rstn(resetn),
        .req0(req[0]), .req1(req[1]),
        .data0(1'b0), .data1(1'b1),
        .ack0(ack_n[0]), .ack1(ack_n[1]),
        .fpa_req(grant), .data_out(origin), .ack_fpa(grant_ack_n)
    );    
`elsif FPATree
    assign ack = ~ack_n;
    fpa_btree #(.N(N), .WIDTH(WIDTH), .NUM_BUFFERS(NUM_BUFFERS)) arb (
        .rstn(resetn), .req(req), .ack(ack_n),
        .root_req(grant), .data_out(origin), .ack_root(grant_ack_n)
    );
`elsif RRATree 
    assign ack = ~ack_n;
    rra_btree #(.N(N), .WIDTH(WIDTH), .NUM_BUFFERS(NUM_BUFFERS)) arb (
        .rstn(resetn), .req(req), .ack(ack_n),
        .root_req(grant), .data_out(origin), .ack_root(grant_ack_n)
    );
`elsif BothTrees 
    // FPA cell on ch0/ch1 -> grant/origin, RRA cell on ch2/ch3 -> grant_b/origin_b
    generate if (N != 4) begin : g_both_requires_four
        both_requires_N_CHANNELS_eq_4 u_elab_error();
    end endgenerate

    wire fpa_origin, rra_origin;
    assign ack = ~ack_n;

    fpa_2to1 #(.WIDTH(1), .NUM_BUFFERS(NUM_BUFFERS)) fpa_arb (
        .rstn(resetn),
        .req0(req[0]), .req1(req[1]),
        .data0(1'b0),  .data1(1'b1),
        .ack0(ack_n[0]), .ack1(ack_n[1]),
        .fpa_req(grant), .data_out(fpa_origin), .ack_fpa(grant_ack_n)
    );

    rra_2to1 #(.WIDTH(1), .NUM_BUFFERS(NUM_BUFFERS)) rra_arb (
        .rstn(resetn),
        .req0(req[2]), .req1(req[3]),
        .data0(1'b0),  .data1(1'b1),
        .ack0(ack_n[2]), .ack1(ack_n[3]),
        .fpa_req(grant_b), .data_out(rra_origin), .ack_fpa(~grant_ack_b)
    );

    assign origin   = {1'b0, fpa_origin};   // 00 = ch0, 01 = ch1
    assign origin_b = {1'b1, rra_origin};   // 10 = ch2, 11 = ch3
`else
    no_design_selected_check_config_vh u_elab_error();
    
`endif

endmodule
