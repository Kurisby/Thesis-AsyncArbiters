`timescale 1ns/1ps

module apd_req_latch (
    input  wire resetn, 
    
    input  wire pulse,      // raw APD
    input  wire ack,        // async clear
    output wire req         // resampled
);

    (* keep = "true", dont_touch = "true" *) reg req_r = 1'b0;

    wire clr = ~resetn | ack;

    always @(posedge pulse or posedge clr) begin
        if (clr) req_r <= 1'b0;
        else     req_r <= 1'b1;
    end

    assign req = req_r;

endmodule
