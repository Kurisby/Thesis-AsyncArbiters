`timescale 1ns / 1ps

`include "config.vh"

module photon_counter_top (
    // AXI-Lite
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [5:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [5:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Initial values
    input  wire        clk,           // 100MHz - from clk_wiz_0
    input  wire        resetn,        // active low - from rst_clk_wiz_0_100M

    // Arbiter channel pins from PMOD
    input  wire        apd_pulse_0,
    input  wire        apd_pulse_1,
    input  wire        apd_pulse_2,
    input  wire        apd_pulse_3
);

// AXI register outputs
wire        ctrl_reset;

localparam N     = 4;
localparam WIDTH = 2;

`ifdef BothTrees
localparam CNT_DELAY = 12;
`else
localparam CNT_DELAY = 6;
`endif

// Signal Generator wires
wire        gen_enable, arb_src;
wire [3:0]  gen_src_mask;
wire [3:0]  gen_chmask;
wire [7:0]  gen_pulsew;
wire [31:0] gen_period, gen_phase, gen_ngroups;
wire [3:0]  gen_pulse;
wire [31:0] events_fired, collision_count;

wire [3:0]  arb_pulse;              // muxed latch inputs
wire [3:0]  arb_req, arb_ack;
wire        arb_grant, arb_gack;
wire [WIDTH-1:0] arb_origin;
wire [32*N-1 :0] counts_grant_raw;

`ifdef BothTrees
wire               arb_grant_b, arb_gack_b;// RRA cell (ch2/ch3)
wire [WIDTH-1:0] arb_origin_b;             // 2'b10 / 2'b11
wire [63:0]        counts_grant_raw_b;     // ch3 (32 bits), ch2 (32 bits)
`endif

// sync counters (from count_sync to axi_lite)
wire [31:0] count_grant0_sync, count_grant1_sync, count_grant2_sync, count_grant3_sync;

// pin_pulse = PMOD pulses
// gen_src_mask = per channel source select (1 = pin, 0 = SigGen)
wire [3:0]  pin_pulse = {apd_pulse_3, apd_pulse_2, apd_pulse_1, apd_pulse_0};
wire [3:0]  src_mask  = arb_src ? 4'hF : gen_src_mask;  // legacy, arb_src always '0'
assign arb_pulse = (src_mask & pin_pulse) | (~src_mask & gen_pulse);

// Combined reset - PS ctrl_reset OR hardware resetn (1-cycle pulse from CTRL bit1)
wire        resetn_combined = resetn & ~ctrl_reset;

// ==========================================================================
// In-Fabric Generated Pulses
// ==========================================================================
signal_gen #(.N(N)) 
    sig_gen (.clk             (clk),
             .resetn          (resetn_combined),
             .enable          (gen_enable),
             .ch_mask         (gen_chmask),
             .period          (gen_period),
             .n_events        (gen_ngroups),
             .phase           (gen_phase),
             .pulse_w         (gen_pulsew),
             .pulse           (gen_pulse),
             .events_fired    (events_fired),   // read via GEN_EVENTS in SDK
             .collision_count (collision_count)
);

// ==========================================================================
// Latched in Signals
// ==========================================================================
apd_req_latch lat_ch0 (.resetn(resetn_combined), .pulse(arb_pulse[0]), .ack(arb_ack[0]), .req(arb_req[0])); // Ch0
apd_req_latch lat_ch1 (.resetn(resetn_combined), .pulse(arb_pulse[1]), .ack(arb_ack[1]), .req(arb_req[1])); // Ch1
apd_req_latch lat_ch2 (.resetn(resetn_combined), .pulse(arb_pulse[2]), .ack(arb_ack[2]), .req(arb_req[2])); // Ch2
apd_req_latch lat_ch3 (.resetn(resetn_combined), .pulse(arb_pulse[3]), .ack(arb_ack[3]), .req(arb_req[3])); // Ch3

// ==========================================================================
// Arbiters (No Arbiter, FPA Tree, RRA Tree, or Both FPA/RRA Cells), (from latch -> arbiters)
// ==========================================================================
arbiter_wrap #(.N(N), .WIDTH(WIDTH), .NUM_BUFFERS(2)) 
    arbiters (.resetn (resetn_combined),
              .req    (arb_req),
              .ack    (arb_ack),      // output
              .grant  (arb_grant),    // output
              .origin (arb_origin),   // output
              .grant_ack (arb_gack)
    
`ifdef BothTrees
             ,.grant_b     (arb_grant_b),  // output
              .origin_b    (arb_origin_b), // output
              .grant_ack_b (arb_gack_b)
`endif
);

// ==========================================================================
// Async Counter (from arbiters -> async)
// ==========================================================================
count_async #(.N(N), .WIDTH(WIDTH), .ARB_DELAY(6), .CNT_DELAY(CNT_DELAY)) 
    async_grant (.resetn      (resetn_combined),
                 .grant       (arb_grant),
                 .origin      (arb_origin),
                 .grant_ack   (arb_gack),
                 .counts_async(counts_grant_raw)
);

`ifdef BothTrees
count_async #(.N(2), .WIDTH(1), .ARB_DELAY(6), .CNT_DELAY(CNT_DELAY)) 
    async_grantb (.resetn      (resetn_combined),
                  .grant       (arb_grant_b),
                  .origin      (arb_origin_b[0]),
                  .grant_ack   (arb_gack_b),
                  .counts_async(counts_grant_raw_b)
);
`endif

// ==========================================================================
// Sync Counters (from async -> sync)
// ==========================================================================
// Ch0
count_sync sync_grant0 (.clk(clk), .resetn(resetn_combined),
                        .count_async(counts_grant_raw[31:0]),   
                        .count_sync_out(count_grant0_sync));
// Ch1
count_sync sync_grant1 (.clk(clk), .resetn(resetn_combined),
                        .count_async(counts_grant_raw[63:32]),  
                        .count_sync_out(count_grant1_sync));               
`ifdef BothTrees
// Ch2 (or RRA Cell Ch0)
count_sync sync_grant2 (.clk(clk), .resetn(resetn_combined),
                        .count_async(counts_grant_raw_b[31:0]),
                        .count_sync_out(count_grant2_sync));
// Ch3 (or RRA Cell Ch1)
count_sync sync_grant3 (.clk(clk), .resetn(resetn_combined),
                        .count_async(counts_grant_raw_b[63:32]),
                        .count_sync_out(count_grant3_sync));                        
`else
// Ch2
count_sync sync_grant2 (.clk(clk), .resetn(resetn_combined),
                        .count_async(counts_grant_raw[95:64]),
                        .count_sync_out(count_grant2_sync));
// Ch3
count_sync sync_grant3 (.clk(clk), .resetn(resetn_combined),
                        .count_async(counts_grant_raw[127:96]),
                        .count_sync_out(count_grant3_sync));
`endif

// ==========================================================================
// AXI Lite Slave - Registers
// ==========================================================================
axi_lite_slave #(.ADDR_WIDTH(6)) 
    axi_regs (.s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
              .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
              .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
              .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
              .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
              .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
              
              // Arbiter
              .collision_count(collision_count), // collisions counted per channel
              .count_grant0(count_grant0_sync),  // ch0 count
              .count_grant1(count_grant1_sync),  // ch1 count
              .count_grant2(count_grant2_sync),  // ch2 count
              .count_grant3(count_grant3_sync),  // ch3 count
              .gen_enable(gen_enable),           // signal generator enable
              .arb_src(arb_src),                 // legacy: used for bitmasking between PMOD/SigGen (no longer needed, but keep it here)
              .gen_src_mask(gen_src_mask),       // SigGen: determines which SPAD pulse we're using: real APD (external PMOD) or SigGen
              .gen_chmask(gen_chmask),           // SigGen: channel mask for which channels to use
              .gen_pulsew(gen_pulsew),           // SigGen: set pulse width; >=10ns (or '1')
              .gen_period(gen_period),           // SigGen: set period; >=20ns (or '1')
              .gen_phase(gen_phase),             // SigGen: set phase; 10ns
              .gen_ngroups(gen_ngroups),         // SigGen: set total number of events per channel
              
              .ctrl_reset(ctrl_reset)            // software (SDK) reset
);

endmodule