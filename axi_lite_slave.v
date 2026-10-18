`timescale 1ns / 1ps

module axi_lite_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6
)(
    input  wire                      s_axi_aclk,
    input  wire                      s_axi_aresetn,

    input  wire [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire                      s_axi_awvalid,
    output reg                       s_axi_awready,

    input  wire [DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  wire                      s_axi_wvalid,
    output reg                       s_axi_wready,

    output reg  [1:0]                s_axi_bresp,
    output reg                       s_axi_bvalid,
    input  wire                      s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire                      s_axi_arvalid,
    output reg                       s_axi_arready,

    output reg  [DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                s_axi_rresp,
    output reg                       s_axi_rvalid,
    input  wire                      s_axi_rready,

    // arbiter: counts + collision generator I/O
    input  wire [31:0]               collision_count, // clk domain - direct
    input  wire [31:0]               count_grant0,    // ch0 counts
    input  wire [31:0]               count_grant1,    // ch1 counts
    input  wire [31:0]               count_grant2,    // ch2 counts
    input  wire [31:0]               count_grant3,    // ch3 counts
    
    // software ctrl: primarily for signal generator 
    output reg                       gen_enable,
    output reg                       arb_src,         // 0 = signal_gen , 1 = PMOD [don't use]
    output reg  [3:0]                gen_src_mask,    // per-channel: 0 = signal_gen, 1 = PMOD
    output reg  [3:0]                gen_chmask,
    output reg  [7:0]                gen_pulsew,
    output reg  [31:0]               gen_period,
    output reg  [31:0]               gen_phase,       // 8 bits per channel
    output reg  [31:0]               gen_ngroups,

    output reg                       ctrl_reset
);

localparam ADDR_CTRL       = 6'h14;
// [was legacy variable]   = 6'h18;
localparam ADDR_COLLISION  = 6'h1C;
localparam ADDR_GRANT_CH0  = 6'h20;
localparam ADDR_GRANT_CH1  = 6'h24;
localparam ADDR_GRANT_CH2  = 6'h28;
localparam ADDR_GRANT_CH3  = 6'h2C;
localparam ADDR_GEN_CTRL   = 6'h30;
localparam ADDR_GEN_PERIOD = 6'h34;
localparam ADDR_GEN_PHASE  = 6'h38;
localparam ADDR_GEN_NEV    = 6'h3C;

reg [ADDR_WIDTH-1:0] awaddr_lat;
reg [ADDR_WIDTH-1:0] araddr_lat;

// Write address channel
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_awready <= 1'b0;
        awaddr_lat    <= 0;
    end else begin
        if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
            s_axi_awready <= 1'b1;
            awaddr_lat    <= s_axi_awaddr;
        end else begin
            s_axi_awready <= 1'b0;
        end
    end
end

// Write data channel
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_wready <= 1'b0;
    end else begin
        if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid) begin
            s_axi_wready <= 1'b1;
        end else begin
            s_axi_wready <= 1'b0;
        end
    end
end

// Register write logic
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        ctrl_reset    <= 1'b0;
        gen_enable    <= 1'b0;
        arb_src       <= 1'b0;          // signal_gen drives the latches
        gen_src_mask  <= 4'h0;          // all channels from signal_gen
        gen_chmask    <= 4'hF;
        gen_pulsew    <= 8'd2;
        gen_period    <= 32'd40;
        gen_phase     <= 32'd0;
        gen_ngroups   <= 32'd0;
    end else begin
        ctrl_reset <= 1'b0;             // auto-clearing pulse

        if (s_axi_awready && s_axi_awvalid &&
            s_axi_wready  && s_axi_wvalid) begin
            case (awaddr_lat[5:0])      
                ADDR_CTRL: begin
                    ctrl_reset <= s_axi_wdata[1];
                end
                ADDR_GEN_CTRL: begin
                    gen_enable   <= s_axi_wdata[0];
                    arb_src      <= s_axi_wdata[1];
                    gen_chmask   <= s_axi_wdata[7:4];
                    gen_pulsew   <= s_axi_wdata[15:8];
                    gen_src_mask <= s_axi_wdata[19:16];
                end
                ADDR_GEN_PERIOD: gen_period  <= s_axi_wdata;
                ADDR_GEN_PHASE:  gen_phase   <= s_axi_wdata;
                ADDR_GEN_NEV:    gen_ngroups <= s_axi_wdata;
                default: ; // read-only
            endcase
        end
    end
end

// Write response channel
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_bvalid <= 1'b0;
        s_axi_bresp  <= 2'b00;
    end else begin
        if (s_axi_awready && s_axi_awvalid &&
            s_axi_wready  && s_axi_wvalid  && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b00;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end
end

// Read address channel
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1'b0;
        araddr_lat    <= 0;
    end else begin
        if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
            s_axi_arready <= 1'b1;
            araddr_lat    <= s_axi_araddr;
        end else begin
            s_axi_arready <= 1'b0;
        end
    end
end

// Read data channel
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_rvalid <= 1'b0;
        s_axi_rresp  <= 2'b00;
        s_axi_rdata  <= 32'd0;
    end else begin
        if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
            s_axi_rvalid <= 1'b1;
            s_axi_rresp  <= 2'b00;
            case (araddr_lat[5:0])
                ADDR_CTRL:       s_axi_rdata <= {30'd0, ctrl_reset, 1'b0};
                ADDR_COLLISION:  s_axi_rdata <= collision_count;
                ADDR_GRANT_CH0:  s_axi_rdata <= count_grant0;
                ADDR_GRANT_CH1:  s_axi_rdata <= count_grant1;
                ADDR_GRANT_CH2:  s_axi_rdata <= count_grant2;
                ADDR_GRANT_CH3:  s_axi_rdata <= count_grant3;
                ADDR_GEN_CTRL:   s_axi_rdata <= {12'd0, gen_src_mask, gen_pulsew, gen_chmask, 2'd0, arb_src, gen_enable};
                ADDR_GEN_PERIOD: s_axi_rdata <= gen_period;
                ADDR_GEN_PHASE:  s_axi_rdata <= gen_phase;
                ADDR_GEN_NEV:    s_axi_rdata <= gen_ngroups;
                default:         s_axi_rdata <= 32'hDEADBEEF;   // indication for failed address read
            endcase
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end

endmodule