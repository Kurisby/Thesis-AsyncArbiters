`timescale 1ns/1ps

module no_arbiter #(
    parameter N     = 4,
    parameter WIDTH = (N <= 2) ? 1 : $clog2(N)  // if N = 4, WIDTH = 2
) (
    input  wire             resetn,

    input  wire [N-1:0]     req,
    output wire [N-1:0]     ack,

    output wire             grant,
    output wire [WIDTH-1:0] origin,
    input  wire             grant_ack
);

    // OR gating all requests
    // any overlapping events merge into one grant
    assign grant = resetn & (|req);

    // on grant_ack, clear every requesting latch (merged events are lost)
    assign ack = {N{grant_ack}} & req;

    // lowest-index active channel
    reg [WIDTH-1:0] org_r;
    generate
        if (N == 4) begin : fourCh
            always @(*) begin
                if (req[0]) 
                    org_r = 2'b00;
                else if (req[1]) 
                    org_r = 2'b01;
                else if (req[2]) 
                    org_r = 2'b10;
                else if (req[3]) 
                    org_r = 2'b11;
                else             
                    org_r = 2'b00;
            end
        end
        else if (N == 2) begin : twoCh
            always @(*) begin
                if (req[0]) 
                    org_r = 1'b0;
                else if (req[1]) 
                    org_r = 1'b1;
                else             
                    org_r = 1'b0;
            end
        end
    endgenerate
    
    assign origin = org_r;

endmodule
