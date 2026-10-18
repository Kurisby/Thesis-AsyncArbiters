`timescale 1ns/1ps

module count_async #(
    parameter N          = 4,    // number of channels
    parameter WIDTH      = 2,    // origin width
    parameter ARB_DELAY  = 6,    // ack latency 
    parameter CNT_DELAY  = 6     // count latency
) (
    input  wire               resetn,

    input  wire               grant,        // channel grant arrival
    input  wire [WIDTH-1:0]   origin,       // channel origin arrival
    output wire               grant_ack,    // ack to arbiter

    output wire [32*N-1:0]    counts_async  // total counts with all channels
);

    // Splits delays passed down from top by half
    // half to origin delay, and the other half to the arbiter delay
    localparam ORG_DELAY = (ARB_DELAY >= 2) ? (ARB_DELAY / 2) : 0;

    // timers for when origin and count are ready to be received
    wire origin_clk;
    wire cnt_clk;
    
    // registers for origin and count
    (* keep = "true" *) reg  [WIDTH-1:0]  origin_r = {WIDTH{1'b0}};
    (* keep = "true" *) reg  [31:0]       cnt [0:N-1];

    // Arbiter Ack Delay
    buffer #(.NUM_BUFFERS(ORG_DELAY))              origin_buffer (.in(grant),      .out(origin_clk));
    buffer #(.NUM_BUFFERS(ARB_DELAY - ORG_DELAY))  arbitr_buffer (.in(origin_clk), .out(grant_ack));
    
    // Async Count Delay
    buffer #(.NUM_BUFFERS(CNT_DELAY))         u_cnt_clk  (.in(grant_ack),  .out(cnt_clk));

    // Origin capture (half less delay than grant delay)
    always @(posedge origin_clk or negedge resetn) begin
        if (!resetn) 
            origin_r <= {WIDTH{1'b0}};
        else         
            origin_r <= origin;
    end

// This allows FPA/RRA Tree and Cells to work together in one project workspace
generate
// ==================================================================
// N = 4
// ==================================================================    

    if (N == 4) begin: Trees // or No Arbiter (4x1)
        // Async Counters
        always @(posedge cnt_clk or negedge resetn) begin
            if (!resetn) begin
                cnt[0] <= 32'd0;
                cnt[1] <= 32'd0;
                cnt[2] <= 32'd0;
                cnt[3] <= 32'd0;
            end else begin
                if (origin_r == 2'b00) 
                    cnt[0] <= cnt[0] + 32'b1;
                if (origin_r == 2'b01) 
                    cnt[1] <= cnt[1] + 32'b1;
                if (origin_r == 2'b10) 
                    cnt[2] <= cnt[2] + 32'b1;
                if (origin_r == 2'b11) 
                    cnt[3] <= cnt[3] + 32'b1;
            end
        end
        
        // Output bus for counters
        assign counts_async[31:0]   = cnt[0];
        assign counts_async[63:32]  = cnt[1];
        assign counts_async[95:64]  = cnt[2];
        assign counts_async[127:96] = cnt[3];
    end
        
// ==================================================================
// N = 2
// ==================================================================    

    else if (N == 2) begin: Cells // or No Arbiter (2x1)
        // Async Counters
        always @(posedge cnt_clk or negedge resetn) begin
            if (!resetn) begin
                cnt[0] <= 32'd0;
                cnt[1] <= 32'd0;
            end else begin
                if (origin_r == 1'b0) 
                    cnt[0] <= cnt[0] + 32'b1;
                if (origin_r == 1'b1) 
                    cnt[1] <= cnt[1] + 32'b1;
            end
        end
        
        // Output bus for counters
        assign counts_async[31:0]   = cnt[0];
        assign counts_async[63:32]  = cnt[1];
    end
    
endgenerate

endmodule