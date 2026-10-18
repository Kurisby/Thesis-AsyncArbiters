`timescale 1ns / 1ps

module buffer #(
    parameter NUM_BUFFERS   = 1
) (
    input  wire in,
    output wire out
    );

// Behavioral simulation oly
`ifdef SIM
    assign #(NUM_BUFFERS * 0.1) out = in;
    
// For hardware
`else    
    genvar b;
    generate
        if (NUM_BUFFERS == 0) begin : buffer_passthru
            assign out = in;
        end
        else begin : buffer_chain
            (* dont_touch = "true" *) wire [NUM_BUFFERS:0] chain;
            assign chain[0] = in;
            for (b = 0; b < NUM_BUFFERS; b = b + 1) begin : b_chain
                (* dont_touch = "true" *) LUT1 #(.INIT(2'b10)) u_lut (.I0(chain[b]), .O(chain[b+1]));
            end
            
            assign out = chain[NUM_BUFFERS];
        end
    endgenerate
    
`endif

endmodule
