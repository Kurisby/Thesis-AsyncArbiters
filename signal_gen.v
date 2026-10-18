`timescale 1ns / 1ps

module signal_gen #(
    parameter N = 4
) (
    input  wire            clk,
    input  wire            resetn,

    // control (AXI-side, clk domain)
    input  wire            enable,         // level; rising edge restarts a burst
    input  wire [N-1:0]    ch_mask,        // per channel enable
    input  wire [31:0]     period,         // clk cycles per event (>= max phase + pulse_w)
    input  wire [31:0]     n_events,       // number of events requested per enabled channel; 0 = free run
    input  wire [8*N-1:0]  phase,          // per-channel start offset, cycles
    input  wire [7:0]      pulse_w,        // pulse width, cycles

    // stimulus out
    output wire [N-1:0]    pulse,          // generated signal pulse (event)

    // ground truth (clk domain, safe for AXI to read directly)
    output reg  [31:0]     events_fired,   // number of injected counts per enabled channel
    output reg  [31:0]     collision_count // number of (expected) collisions per burst
);

// ==================================================================
// Master Timing Engine
// ==================================================================
    reg  [31:0] cyc;         // position within the current events (1 cyc = 10ns)
    reg  [31:0] evt;         // events completed this burst
    reg         running;     // signal generator is 'running'
    reg         enable_d;    // enable, but (d)elayed by one block

    // when all signals have been generated
    wire        burst_done = (n_events != 32'd0) && (evt >= n_events);
    
    // `running` clears one cycle AFTER evt reaches n_events
    wire        live = running & ~burst_done;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cyc <= 32'd0; 
            evt <= 32'd0; 
            running <= 1'b0; 
            enable_d <= 1'b0;
            events_fired <= 32'd0;
        end else begin
            enable_d <= enable;
            // START: detects signal generation request
            if (enable & ~enable_d) begin
                cyc <= 32'd0; 
                evt <= 32'd0; 
                running <= 1'b1;
                events_fired <= 32'd0;
            end
            // need 'enable' beforehand
            else if (running) begin
                // END: halt running
                if (!enable || burst_done) begin
                    running <= 1'b0;
                end
                // CONTINUE: finished 1 pulse/event
                else if (cyc == period - 32'd1) begin
                    cyc <= 32'd0;
                    evt <= evt + 32'd1;
                    events_fired <= events_fired + 32'd1;
                end
                // CONTINUE: keep counting, partially through 1 pulse
                else begin
                    cyc <= cyc + 32'd1;
                end
            end
        end
    end

/* 
NOTE: events_fired increments at events END, so it equals the number
of COMPLETED events = events actually injected per enabled channel.
*/
  
// ==================================================================
// Unrolled Per-Channel Pulse Shaping & Collision Detection
// ==================================================================
    wire coll_now; 

    generate
// ==================================================================
// N = 4
// ==================================================================    
        if (N == 4) begin : gen_ch4
            reg [3:0] pr;
            
            // Pulse shaper block
            always @(posedge clk or negedge resetn) begin
                if (!resetn) 
                    pr <= 4'b0;
                else begin
                    // doesn't give any channels a pulse until these four requirements are met:
                    pr[0] <= live & // checks if signal generator is live
                             ch_mask[0] & // masks onto ch0
                             (cyc >= {24'd0, phase[7:0]}) & // HIGH if it reaches the phase range, else LOW
                             (cyc <  {24'd0, phase[7:0]} + {24'd0, pulse_w}); // HIGH if it's within pulse width range
                    pr[1] <= live & ch_mask[1] & (cyc >= {24'd0, phase[15:8]})  & (cyc < {24'd0, phase[15:8]}  + {24'd0, pulse_w});
                    pr[2] <= live & ch_mask[2] & (cyc >= {24'd0, phase[23:16]}) & (cyc < {24'd0, phase[23:16]} + {24'd0, pulse_w});
                    pr[3] <= live & ch_mask[3] & (cyc >= {24'd0, phase[31:24]}) & (cyc < {24'd0, phase[31:24]} + {24'd0, pulse_w});
                end
            end
            assign pulse = pr;
            
            // Collision Detection for N=4
            wire [2:0] act; 
            assign act = pr[0] + pr[1] + pr[2] + pr[3];
            assign coll_now = (act >= 2);
        end
        
// ==================================================================
// N = 2
// ==================================================================    
        else if (N == 2) begin : gen_ch2
            reg [1:0] pr;
            
            always @(posedge clk or negedge resetn) begin
                if (!resetn) 
                    pr <= 2'b0;
                else begin
                    pr[0] <= live & ch_mask[0] & (cyc >= {24'd0, phase[7:0]})  & (cyc < {24'd0, phase[7:0]}  + {24'd0, pulse_w});
                    pr[1] <= live & ch_mask[1] & (cyc >= {24'd0, phase[15:8]}) & (cyc < {24'd0, phase[15:8]} + {24'd0, pulse_w});
                end
            end
            assign pulse = pr;
            
            // Collision Detection for N=2
            assign coll_now = (pr[0] & pr[1]); 
        end
    endgenerate

// ==================================================================
// Collision Counter (Rising Edge Tracked)
// ==================================================================
    reg coll_d;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            coll_d <= 1'b0; collision_count <= 32'd0;
        end 
        else begin
            coll_d <= coll_now;
            if (coll_now & ~coll_d) 
                collision_count <= collision_count + 32'd1;
        end
    end

endmodule