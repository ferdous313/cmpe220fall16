
module l2cache_pipe_wp(
    input                                 clk,
    input                                 reset,

    //---------------------------
    // L1 (icache or dcache)<->l2cache_pipe interface
    
    // input  I_l1tol2_req_type             l1tol2_req,
    input                                 l1tol2_req_valid,
    output                                l1tol2_req_retry,
      // Dispatching
    input   L1_reqid_type                 l1tol2_req_dcid,
    input   SC_cmd_type                   l1tol2_req_cmd,
    input   SC_pcsign_type                l1tol2_req_pcsign,
    input   SC_laddr_type                 l1tol2_req_laddr,
    input   SC_sptbr_type                 l1tol2_req_sptbr,
    
    // output I_l2tol1_snack_type           l2tol1_snack,
    output                                l2tol1_snack_valid,
    input                                 l2tol1_snack_retry,
      // Dispatching
    output  L1_reqid_type                 l2tol1_snack_dcid,
    output  L2_reqid_type                 l2tol1_snack_l2id,
    output  SC_snack_type                 l2tol1_snack_snack,
        // output  SC_line_type             l2tol1_snack_line,
    output  logic [63:0]                  l2tol1_snack_line7,
    output  logic [63:0]                  l2tol1_snack_line6,
    output  logic [63:0]                  l2tol1_snack_line5,
    output  logic [63:0]                  l2tol1_snack_line4,
    output  logic [63:0]                  l2tol1_snack_line3,
    output  logic [63:0]                  l2tol1_snack_line2,
    output  logic [63:0]                  l2tol1_snack_line1,
    output  logic [63:0]                  l2tol1_snack_line0,
    output  SC_paddr_type                 l2tol1_snack_paddr,
    output  SC_dctlbe_type                l2tol1_snack_dctlbe,
    
    // input I_l2snoop_ack_type             l2snoop_ack,
    input                                 l1tol2_snoop_ack_valid,
    output                                l1tol2_snoop_ack_retry,
      // Dispatching
    input   L2_reqid_type                 l1tol2_snoop_ack_l2id,
    
    // input I_l1tol2_disp_type             l1tol2_disp,
    input                                 l1tol2_disp_valid,
    output                                l1tol2_diso_retry,
      // Dispatching
    input   L1_reqid_type                 l1tol2_disp_l1id,
    input   L2_reqid_type                 l1tol2_disp_l2id,
    input   SC_disp_mask_type             l1tol2_disp_mask,
    input   SC_dcmd_type                  l1tol2_disp_dcmd,
         // input   SC_line_type            l1tol2_disp_line,
    input   logic [63:0]                  l1tol2_disp_line7,
    input   logic [63:0]                  l1tol2_disp_line6,
    input   logic [63:0]                  l1tol2_disp_line5,
    input   logic [63:0]                  l1tol2_disp_line4,
    input   logic [63:0]                  l1tol2_disp_line3,
    input   logic [63:0]                  l1tol2_disp_line2,
    input   logic [63:0]                  l1tol2_disp_line1,
    input   logic [63:0]                  l1tol2_disp_line0,
    input   SC_paddr_type                 l1tol2_disp_paddr,
    
    // output I_l2tol1_dack_type            l2tol1_dack,
    output                                l2tol1_dack_valid,
    input                                 l2tol1_dack_retry,
      // Dispatching
    output  L1_reqid_type                 l2tol1_dack_l1id,
    
    // input  I_pftocache_req_type          pftocache_req,
    input                                 l1tol2_pfreq valid,
    output                                l1tol2_pfreq_retry,
      // Dispatching
    input   SC_laddr_type                 l1tol2_pfreq_laddr,
    input   SC_sptbr_type                 l1tol2_pfreq_sptbr,

    // --------------------------------
    // core Prefetch interface

    // input  I_pftocache_req_type          pftol2_pfreq,
    input                                 pftol2_pfreq_valid,
    output                                pftol2_pfreq_retry,
      // Dispatching
    input   SC_laddr_type                 pftol2_pfreq_laddr,
    input   SC_sptbr_type                 pftol2_pfreq_sptbr,
        
    // output  PF_cache_stats_type          cachetopf_stats,
    output  logic [6:0]                   cachetopf_stats_nhitmissd,
    output  logic [6:0]                   cachetopf_stats_nhitmissp,
    output  logic [6:0]                   cachetopf_stats_nhithit,
    output  logic [6:0]                   cachetopf_stats_nmiss,
    output  logic [6:0]                   cachetopf_stats_ndrop,
    output  logic [6:0]                   cachetopf_stats_nreqs,
    output  logic [6:0]                   cachetopf_stats_nsnoops,
    output  logic [6:0]                   cachetopf_stats_ndisp,
    
    // ---------------------------------
    // Directory interface

    // output  I_l2todr_req_type            l2todr_req,
    output                                l2todr_req_valid,
    input                                 l2todr_req_retry,
      // Dispatching
    output  SC_nodeid_type                l2todr_req_nid, 
    output  L2_reqid_type                 l2todr_req_l2id,
    output  SC_cmd_type                   l2todr_req_cmd,
    output  SC_paddr_type                 l2todr_req_paddr,

    // input  I_drtol2_snack_type           drtol2_snack,
    input                                 drtol2_snack_valid,
    output                                drtol2_snack_retry,
      // Dispatching
    input   SC_nodeid_type                drtol2_snack_nid, 
    input   L2_reqid_type                 drtol2_snack_l2id,
    input   DR_reqid_type                 drtol2_snack_drid,
    input   SC_snack_type                 drtol2_snack_snack,
        // input  SC_line_type              drtol2_snack_line,
    input   logic [63:0]                  drtol2_snack_line7,
    input   logic [63:0]                  drtol2_snack_line6,
    input   logic [63:0]                  drtol2_snack_line5,
    input   logic [63:0]                  drtol2_snack_line4,
    input   logic [63:0]                  drtol2_snack_line3,
    input   logic [63:0]                  drtol2_snack_line2,
    input   logic [63:0]                  drtol2_snack_line1,
    input   logic [63:0]                  drtol2_snack_line0,
    input   SC_paddr_type                 drtol2_snack_paddr,

    // output I_l2snoop_ack_type            l2todr_snoop_ack,
    output                                l2todr_snoop_ack_valid,
    input                                 l2todr_snoop_ack_retry,
    output  L2_reqid_type                 l2todr_snoop_ack_l2id,

    // output I_l2todr_disp_type            l2todr_disp,
    output                                l2todr_disp_valid,
    input                                 l2todr_disp_retry,
      // Dispatching
    output  SC_nodeid_type                l2todr_disp_nid, 
    output  L2_reqid_type                 l2todr_disp_l2id,
    output  DR_reqid_type                 l2todr_disp_drid,
    output  SC_disp_mask_type             l2todr_disp_mask,
    output  SC_dcmd_type                  l2todr_disp_dcmd,
        // SC_line_type                     l2todr_disp_line,
    output  logic [63:0]                  l2todr_disp_line7,
    output  logic [63:0]                  l2todr_disp_line6,
    output  logic [63:0]                  l2todr_disp_line5,
    output  logic [63:0]                  l2todr_disp_line4,
    output  logic [63:0]                  l2todr_disp_line3,
    output  logic [63:0]                  l2todr_disp_line2,
    output  logic [63:0]                  l2todr_disp_line1,
    output  logic [63:0]                  l2todr_disp_line0,
    output  SC_paddr_type                 l2todr_disp_paddr,

    // input  I_drtol2_dack_type            drtol2_dack,
    input                                 drtol2_dack_valid,
    output                                drtol2_dack_retry,
      // Dispatching
    input   SC_nodeid_type                drtol2_dack_nid, 
    input   L2_reqid_type                 drtol2_dack_l2id,

    // output I_pftocache_req_type          l2todr_pdreq,
    output                                l2todr_pfreq_valid,
    input                                 l2todr_pfreq_retry,
      // Dispatching
    output  SC_paddr_type                 l2todr_pfreq_paddr

);

    l2cache_pipe
    l2(
      .clk(clk),
      .reset(reset),

    // L2s interface
      .l1tol2_req_valid(l1tol2_req_valid),
      .l1tol2_req_retry(l1tol2_req_retry),
      .l1tol2_req({     l1tol2_req_dcid,
                        l1tol2_req_cmd,
                        l1tol2_req_pcsign,
                        l1tol2_req_laddr,
                        l1tol2_req_sptbr}),
      
      .l2tol1_snack_valid(l2tol1_snack_valid),
      .l2tol1_snack_retry(l2tol1_snack_retry),
      .l2tol1_snack({     l2tol1_snack_dcid,
                          l2tol1_snack_l2id,
                          l2tol1_snack_snack,
                          l2tol1_snack_line7,
                          l2tol1_snack_line6,
                          l2tol1_snack_line5,
                          l2tol1_snack_line4,
                          l2tol1_snack_line3,
                          l2tol1_snack_line2,
                          l2tol1_snack_line1,
                          l2tol1_snack_line0,
                          l2tol1_snack_paddr,
                          l2tol1_snack_dctlbe}),

       .l1tol2_snoop_ack_valid(l1tol2_snoop_ack_valid),
       .l1tol2_snoop_ack_retry(l1tol2_snoop_ack_retry),
       .l1tol2_snoop_ack(      l1tol2_snoop_ack_l2id),

       .l1tol2_disp_valid(l1tol2_disp_valid),
       .l1tol2_disp_retry(l1tol2_disp_retry),
       .l1tol2_disp({     l1tol2_disp_l1id,
                          l1tol2_disp_l2id,
                          l1tol2_disp_mask,
                          l1tol2_disp_dcmd,
                          l1tol2_disp_line7,
                          l1tol2_disp_line6,
                          l1tol2_disp_line5,
                          l1tol2_disp_line4,
                          l1tol2_disp_line3,
                          l1tol2_disp_line2,
                          l1tol2_disp_line1,
                          l1tol2_disp_line0,
                          l1tol2_disp_paddr}),

        .l2tol1_dack_valid(l2tol1_dack_valid),
        .l2tol1_dack_retry(l2tol1_dack_retry),
        .l2tol1_dack(      l2tol1_dack_l1id),

        .l1tol2_pfreq_valid(l1tol2_pfreq_valid),
        .l1tol2_pfreq_retry(l1tol2_pfreq_retry),
        .l1tol2_pfreq({     l1tol2_pfreq_laddr,
                            l1tol2_pfreq_sptbr}),

        .pftol2_pfreq_valid(pftol2_pfreq_valid),
        .pftol2_pfreq_retry(pftol2_pfreq_vretry),
        .pftol2_pfreq({     pftol2_pfreq_laddr,
                            pftol2_pfreq_sptbr}),

        .cachetopf_stats({  cachetopf_stats_nhitmissd,
                            cachetopf_stats_nhitmissp,
                            cachetopf_stats_nhithit,
                            cachetopf_stats_nmiss,
                            cachetopf_stats_ndrop,
                            cachetopf_stats_nreqs,
                            cachetopf_stats_nsnoops,
                            cachetopf_stats_ndisp}),

        .l2todr_req_valid(l2todr_req_valid),
        .l2todr_req_retry(l2todr_req_retry),
        .l2todr_req({     l2todr_req_nid, 
                          l2todr_req_l2id,
                          l2todr_req_cmd,
                          l2todr_req_paddr}),

        .drtol2_snack_valid(drtol2_snack_valid),
        .drtol2_snack_retry(drtol2_snack_retry),
        .drtol2_snack({     drtol2_snack_nid, 
                            drtol2_snack_l2id,
                            drtol2_snack_drid,
                            drtol2_snack_snack,
                            drtol2_snack_line7,
                            drtol2_snack_line6,
                            drtol2_snack_line5,
                            drtol2_snack_line4,
                            drtol2_snack_line3,
                            drtol2_snack_line2,
                            drtol2_snack_line1,
                            drtol2_snack_line0,
                            drtol2_snack_paddr}),

        .l2todr_snoop_ack_valid(l2todr_snoop_ack_valid),
        .l2todr_snoop_ack_retry(l2todr_snoop_ack_retry),
        .l2todr_snoop_ack(      l2todr_snoop_ack_l2id),

        .l2todr_disp_valid(l2todr_disp_valid),
        .l2todr_disp_retry(l2todr_disp_retry),
        .l2todr_disp({     l2todr_disp_nid, 
                           l2todr_disp_l2id,
                           l2todr_disp_drid,
                           l2todr_disp_mask,
                           l2todr_disp_dcmd,
                           l2todr_disp_line7,
                           l2todr_disp_line6,
                           l2todr_disp_line5,
                           l2todr_disp_line4,
                           l2todr_disp_line3,
                           l2todr_disp_line2,
                           l2todr_disp_line1,
                           l2todr_disp_line0,
                           l2todr_disp_paddr}),

         .drtol2_dack_valid(drtol2_dack_valid),
         .drtol2_dack_retry(drtol2_dack_retry),
         .drtol2_dack({     drtol2_dack_nid, 
                            drtol2_dack_l2id}),

         .l2todr_pfreq_valid(l2todr_pfreq_valid),
         .l2todr_pfreq_retry(l2todr_pfreq_retry),
         .l2todr_pfreq(      l2todr_pfreq_paddr)

      );

endmodule
