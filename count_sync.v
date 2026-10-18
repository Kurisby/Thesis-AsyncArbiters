`timescale 1ns / 1ps

module count_sync (
    input  wire        clk,            // 100MHz AXI clock domain
    input  wire        resetn,         // active low reset
    input  wire [31:0] count_async,    // raw count from async counter
    output reg  [31:0] count_sync_out  // synchronized binary count
);

// ==================================================================
// ASYNCHRONOUS DOMAIN
// ==================================================================

// Binary to Gray code
// -> Only 1 bit changes per increment
wire [31:0] gray_async;

genvar i;
generate
    for (i = 0; i < 31; i = i + 1) begin : b2g
        assign gray_async[i] = count_async[i] ^ count_async[i+1];
    end
endgenerate
assign gray_async[31] = count_async[31];

// ==================================================================

// ------------------------------------------------------------------
// NO MANS LAND - the lands of inbetween
// ------------------------------------------------------------------

// Two flip-flop synchronizers (CDC)
reg [31:0] gray_sync1, gray_sync2;

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        gray_sync1 <= 32'd0;
        gray_sync2 <= 32'd0;
    end else begin
        gray_sync1 <= gray_async;   // First FF  - may be metastable
        gray_sync2 <= gray_sync1;   // Second FF - insurance
    end
end

// ------------------------------------------------------------------

// ==================================================================
// SYNCHRONOUS DOMAIN
// ==================================================================

// Gray code to Binary
wire [31:0] binary_sync;

assign binary_sync[31] = gray_sync2[31];

genvar j;
generate
    for (j = 30; j >= 0; j = j - 1) begin : g2b
        assign binary_sync[j] = binary_sync[j+1] ^ gray_sync2[j];
    end
endgenerate

// Register the final output
always @(posedge clk or negedge resetn) begin
    if (!resetn)
        count_sync_out <= 32'd0;
    else
        count_sync_out <= binary_sync;
end

// ==================================================================

endmodule