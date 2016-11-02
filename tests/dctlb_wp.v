/* this file automatically generated by make_wp.py script
 * for file rtl/dctlb.v
 * for module dctlb
 * with the instance name dctlb_dut
 */


// DCTLB runs parallel to the Dcache. It gets the same requests as the dcache,
// and sends the translation a bit after. It also has a command channel to
// notify for when checkpoints are finished from the TLB point of view.
//
// The DCTLB has to track at least 4 SPBTRs at once, but no need to have
// unlimited. This means that just 4 flops translating SBPTR to valid indexes
// are enough. If a new SBPTR checkpoint create arrives, the TLB can
// invalidate all the associated TLB entries (and notify the L1 accordingly)
//
//
// The hpaddr is a way to identify a L2TLB entry. It is also a pseudo-hah of
// the paddr. When a L2TLB entry is displaced, the dctlb gets a snoop.
// This means that when a hpaddr gets removed, it has to disappear from
// the L1 cache

`define L1DT_PASSTHROUGH

module dctlb_wp(
  /* verilator lint_off UNUSED */
    input   logic               clk
    ,input  logic               reset

  // ld core interface
    ,input  logic               coretodctlb_ld_valid
    ,output logic               coretodctlb_ld_retry
    //  ,input  I_coretodctlb_ld_type    coretodctlb_ld
    ,input  DC_ckpid_type       coretodctlb_ld_ckpid
    ,input  CORE_reqid_type     coretodctlb_ld_coreid
    ,input  CORE_lop_type       coretodctlb_ld_lop
    ,input  logic               coretodctlb_ld_pnr
    ,input  SC_laddr_type       coretodctlb_ld_laddr
    ,input  SC_imm_type         coretodctlb_ld_imm
    ,input  SC_sptbr_type       coretodctlb_ld_sptbr
    ,input  logic               coretodctlb_ld_user

  // st core interface
    ,input  logic               coretodctlb_st_valid
    ,output logic               coretodctlb_st_retry
    //  ,input  I_coretodctlb_st_type    coretodctlb_st
    ,input  DC_ckpid_type       coretodctlb_st_ckpid
    ,input  CORE_reqid_type     coretodctlb_st_coreid
    ,input  CORE_mop_type       coretodctlb_st_mop
    ,input  logic               coretodctlb_st_pnr
    ,input  SC_laddr_type       coretodctlb_st_laddr
    ,input  SC_imm_type         coretodctlb_st_imm
    ,input  SC_sptbr_type       coretodctlb_st_sptbr
    ,input  logic               coretodctlb_st_user

  // prefetch request (uses the st/ld fwd port opportunistically)
    ,input  logic               pfetol1tlb_req_valid
    ,output logic               pfetol1tlb_req_retry
    //  ,input  I_pfetol1tlb_req_type    pfetol1tlb_req
    ,input  logic               pfetol1tlb_req_l2
    ,input  SC_laddr_type       pfetol1tlb_req_laddr
    ,input  SC_sptbr_type       pfetol1tlb_req_sptbr

  // forward ld core interface
    ,output logic               l1tlbtol1_fwd0_valid
    ,input  logic               l1tlbtol1_fwd0_retry
    //  ,output I_l1tlbtol1_fwd_type     l1tlbtol1_fwd0
    ,output CORE_reqid_type     l1tlbtol1_fwd0_coreid
    ,output logic               l1tlbtol1_fwd0_prefetch
    ,output logic               l1tlbtol1_fwd0_l2_prefetch
    ,output SC_fault_type       l1tlbtol1_fwd0_fault
    ,output TLB_hpaddr_type     l1tlbtol1_fwd0_hpaddr
    ,output SC_ppaddr_type      l1tlbtol1_fwd0_ppaddr

  // forward st core interface
    ,output logic               l1tlbtol1_fwd1_valid
    ,input  logic               l1tlbtol1_fwd1_retry
    //  ,output I_l1tlbtol1_fwd_type     l1tlbtol1_fwd1
    ,output CORE_reqid_type     l1tlbtol1_fwd1_coreid
    ,output logic               l1tlbtol1_fwd1_prefetch
    ,output logic               l1tlbtol1_fwd1_l2_prefetch
    ,output SC_fault_type       l1tlbtol1_fwd1_fault
    ,output TLB_hpaddr_type     l1tlbtol1_fwd1_hpaddr
    ,output SC_ppaddr_type      l1tlbtol1_fwd1_ppaddr

  // Notify the L1 that the index of the TLB is gone
  /* verilator lint_off UNDRIVEN */
    ,output logic               l1tlbtol1_cmd_valid
    ,input  logic               l1tlbtol1_cmd_retry
    //  ,output I_l1tlbtol1_cmd_type     l1tlbtol1_cmd
    ,output logic               l1tlbtol1_cmd_flush
    ,output TLB_hpaddr_type     l1tlbtol1_cmd_hpaddr

  // Interface with the L2 TLB
    ,input  logic               l2tlbtol1tlb_snoop_valid
    ,output logic               l2tlbtol1tlb_snoop_retry
    //  ,input I_l2tlbtol1tlb_snoop_type l2tlbtol1tlb_snoop
    ,input  TLB_reqid-type      l2tlbtol1tlb_snoop_rid
    ,input  TLB_hpaddr_type     l2tlbtol1tlb_snoop_hpaddr

    ,input  logic               l2tlbtol1tlb_ack_valid
    ,output logic               l2tlbtol1tlb_ack_retry
    //  ,input I_l2tlbtol1tlb_ack_type   l2tlbtol1tlb_ack
    ,input  TLB_reqid_type      l2tlbtol1tlb_ack_rid
    ,input  TLB_hpaddr_type     l2tlbtol1tlb_ack_hpaddr
    ,input  SC_ppaddr_type      l2tlbtol1tlb_ack_ppaddr
    ,input  SC_dctlbe_type      l2tlbtol1tlb_ack_dctlbe

    ,output logic               l1tlbtol2tlb_req_valid
    ,input  logic               l1tlbtol2tlb_req_retry
    //  ,output I_l1tlbtol2tlb_req_type  l1tlbtol2tlb_req
    ,output TLB_reqid_type      l1tlbtol2tlb_req_rid
    ,output logic               l1tlbtol2tlb_req_disp_req
    ,output logic               l1tlbtol2tlb_req_disp_A
    ,output logic               l1tlbtol2tlb_req_disp_B
    ,output TLB_hpaddr_type     l1tlbtol2tlb_req_disp_hpaddr
    ,output SC_laddr_type       l1tlbtol2tlb_req_laddr
    ,output SC_sptbr_type       l1tlbtol2tlb_req_sptbr

    ,output logic               l1tlbtol2tlb_sack_valid
    ,input  logic               l1tlbtol2tlb_sack_retry
    //  ,output I_l1tlbtol2tlb_sack_type l1tlbtol2tlb_sack
    ,output TLB_reqid_type      l1tlbtol2tlb_sack_rid
  /* verilator lint_on UNDRIVEN */
  /* verilator lint_on UNUSED */
);




    I_coretodctlb_ld_type coretodctlb_ld;
    assign coretodctlb_ld.ckpid = coretodctlb_ld_ckpid;
    assign coretodctlb_ld.coreid = coretodctlb_ld_coreid;
    assign coretodctlb_ld.lop = coretodctlb_ld_lop;
    assign coretodctlb_ld.pnr = coretodctlb_ld_pnr;
    assign coretodctlb_ld.laddr = coretodctlb_ld_laddr;
    assign coretodctlb_ld.imm = coretodctlb_ld_imm;
    assign coretodctlb_ld.sptbr = coretodctlb_ld_sptbr;
    assign coretodctlb_ld.user = coretodctlb_ld_user;

    I_coretodctlb_st_type coretodctlb_st;
    assign coretodctlb_st.ckpid = coretodctlb_st_ckpid;
    assign coretodctlb_st.coreid = coretodctlb_st_coreid;
    assign coretodctlb_st.mop = coretodctlb_st_mop;
    assign coretodctlb_st.pnr = coretodctlb_st_pnr;
    assign coretodctlb_st.laddr = coretodctlb_st_laddr;
    assign coretodctlb_st.imm = coretodctlb_st_imm;
    assign coretodctlb_st.sptbr = coretodctlb_st_sptbr;
    assign coretodctlb_st.user = coretodctlb_st_user;

    I_pfetol1tlb_req_type pfetol1tlb_req;
    assign pfetol1tlb_req.l2 = pfetol1tlb_req_l2;
    assign pfetol1tlb_req.laddr = pfetol1tlb_req_laddr;
    assign pfetol1tlb_req.sptbr = pfetol1tlb_req_sptbr;

    I_l1tlbtol1_fwd_type l1tlbtol1_fwd0;
    assign l1tlbtol1_fwd0_coreid = l1tlbtol1_fwd0.coreid;
    assign l1tlbtol1_fwd0_prefetch = l1tlbtol1_fwd0.prefetch;
    assign l1tlbtol1_fwd0_l2_prefetch = l1tlbtol1_fwd0.l2_prefetch;
    assign l1tlbtol1_fwd0_fault = l1tlbtol1_fwd0.fault;
    assign l1tlbtol1_fwd0_hpaddr = l1tlbtol1_fwd0.hpaddr;
    assign l1tlbtol1_fwd0_ppaddr = l1tlbtol1_fwd0.ppaddr;

    I_l1tlbtol1_fwd_type l1tlbtol1_fwd1;
    assign l1tlbtol1_fwd1_coreid = l1tlbtol1_fwd1.coreid;
    assign l1tlbtol1_fwd1_prefetch = l1tlbtol1_fwd1.prefetch;
    assign l1tlbtol1_fwd1_l2_prefetch = l1tlbtol1_fwd1.l2_prefetch;
    assign l1tlbtol1_fwd1_fault = l1tlbtol1_fwd1.fault;
    assign l1tlbtol1_fwd1_hpaddr = l1tlbtol1_fwd1.hpaddr;
    assign l1tlbtol1_fwd1_ppaddr = l1tlbtol1_fwd1.ppaddr;

    I_l1tlbtol1_cmd_type l1tlbtol1_cmd;
    assign l1tlbtol1_cmd_flush = l1tlbtol1_cmd.flush;
    assign l1tlbtol1_cmd_hpaddr = l1tlbtol1_cmd.hpaddr;

    I_l2tlbtol1tlb_snoop_type l2tlbtol1tlb_snoop;
    assign l2tlbtol1tlb_snoop.rid = l2tlbtol1tlb_snoop_rid;
    assign l2tlbtol1tlb_snoop.hpaddr = l2tlbtol1tlb_snoop_hpaddr;

    I_l2tlbtol1tlb_ack_type l2tlbtol1tlb_ack;
    assign l2tlbtol1tlb_ack.rid = l2tlbtol1tlb_ack_rid;
    assign l2tlbtol1tlb_ack.hpaddr = l2tlbtol1tlb_ack_hpaddr;
    assign l2tlbtol1tlb_ack.ppaddr = l2tlbtol1tlb_ack_ppaddr;
    assign l2tlbtol1tlb_ack.dctlbe = l2tlbtol1tlb_ack_dctlbe;

    I_l1tlbtol2tlb_req_type l1tlbtol2tlb_req;
    assign l1tlbtol2tlb_req_rid = l1tlbtol2tlb_req.rid;
    assign l1tlbtol2tlb_req_disp_req = l1tlbtol2tlb_req.disp_req;
    assign l1tlbtol2tlb_req_disp_A = l1tlbtol2tlb_req.disp_A;
    assign l1tlbtol2tlb_req_disp_B = l1tlbtol2tlb_req.disp_B;
    assign l1tlbtol2tlb_req_disp_hpaddr = l1tlbtol2tlb_req.disp_hpaddr;
    assign l1tlbtol2tlb_req_laddr = l1tlbtol2tlb_req.laddr;
    assign l1tlbtol2tlb_req_sptbr = l1tlbtol2tlb_req.sptbr;

    I_l1tlbtol2tlb_sack_type l1tlbtol2tlb_sack;
    assign l1tlbtol2tlb_sack_rid = l1tlbtol2tlb_sack.rid;


dctlb dctlb_dut(.*);
endmodule
