`timescale 1ns / 1ps

module data_latch #(
    parameter WIDTH = 1             // width of the data bus (default = 1)
) (
    input                  rstn,    // reset
    input                  req,     // FPA Request (winning photon)
    input      [WIDTH-1:0] D,       // Data Bus (of winning photon)
    output reg [WIDTH-1:0] Q        // Data Bus output
    );
    
// triggered on FPA/RRA Request arrival or user reset
always @(posedge req or negedge rstn) begin
    if (!rstn) begin
        Q <= {WIDTH{1'b0}};
    end
    else begin
        Q <= D;
    end
end

endmodule
