`ifndef CONFIG_VH
`define CONFIG_VH

`ifndef NoArbiter
 `ifndef FPACell
  `ifndef FPATree
   `ifndef RRATree
    `ifndef BothTrees
     `define RRATree             // change this for design
    `endif
   `endif
  `endif
 `endif
`endif

`ifndef N_CHANNELS
 `define N_CHANNELS 4          // must be a power of 2 for the trees; FPACell forces 2
`endif

//`ifndef NUM_BUFFERS
// `define NUM_BUFFERS 8  // Set your desired number of buffers here
//`endif

`endif // CONFIG_VH
