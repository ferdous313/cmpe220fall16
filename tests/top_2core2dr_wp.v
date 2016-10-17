// file automatically generated by top_generator script
// this is a memory hierarchy done as a class project for CMPE220 at UCSC
// this specific file was generated for:
// 2 core(s), 
// 2 data cache slice(s) per core, and
// 2 directory(ies)


module top_2core2dr_wp(
	input	logic				clk
	,input	logic				reset

   //******************************************
   //*  CORE 0                       *
   //******************************************//
   // icache core 0
	,input	logic				core0_coretoic_valid
	,output	logic				core0_coretoic_retry
	,input	logic				SC_laddr_type
	,output	logic				core0_ictocore_valid
	,input	logic				core0_ictocore_retry
	//  ,output I_ictocore_type      core0_ictocore              
	,output	SC_abort_type		core0_ictocore_aborted
	,output	IC_fwidth_type		core0_ictocore_data

   // dcache core 0, slice 0
	,input	logic				core0_slice0_coretodc_ld_valid
	,output	logic				core0_slice0_coretodc_ld_retry
	//  ,input   I_coretodc_ld_type      core0_slice0_coretodc_ld           
	,input	DC_ckpid_type		core0_slice0_coretodc_ld_ckpid
	,input	CORE_reqid_type		core0_slice0_coretodc_ld_coreid
	,input	CORE_lop_type		core0_slice0_coretodc_ld_lop
	,input	logic				core0_slice0_coretodc_ld_pnr
	,input	SC_pcsign_type		core0_slice0_coretodc_ld_pcsign
	,input	SC_laddr_type		core0_slice0_coretodc_ld_laddr
	,input	SC_sptbr_type		core0_slice0_coretodc_ld_sptbr
	,output	logic				core0_slice0_dctocore_ld_valid
	,input	logic				core0_slice0_dctocore_ld_retry
	//  ,output  I_coretodc_ld_type      core0_slice0_dctocore_ld           
	,output	DC_ckpid_type		core0_slice0_dctocore_ld_ckpid
	,output	CORE_reqid_type		core0_slice0_dctocore_ld_coreid
	,output	CORE_lop_type		core0_slice0_dctocore_ld_lop
	,output	logic				core0_slice0_dctocore_ld_pnr
	,output	SC_pcsign_type		core0_slice0_dctocore_ld_pcsign
	,output	SC_laddr_type		core0_slice0_dctocore_ld_laddr
	,output	SC_sptbr_type		core0_slice0_dctocore_ld_sptbr
	,input	logic				core0_slice0_coretodc_std_valid
	,output	logic				core0_slice0_coretodc_std_retry
	//  ,input   I_coretodc_std_type     core0_slice0_coretodc_std          
	,input	DC_ckpid_type		core0_slice0_coretodc_std_ckpid
	,input	CORE_reqid_type		core0_slice0_coretodc_std_coreid
	,input	CORE_mop_type		core0_slice0_coretodc_std_mop
	,input	logic				core0_slice0_coretodc_std_pnr
	,input	SC_pcsign_type		core0_slice0_coretodc_std_pcsign
	,input	SC_laddr_type		core0_slice0_coretodc_std_laddr
	,input	SC_sptbr_type		core0_slice0_coretodc_std_sptbr
	,input	SC_line_type		core0_slice0_coretodc_std_data
	,output	logic				core0_slice0_dctocore_std_ack_valid
	,input	logic				core0_slice0_dctocore_std_ack_retry
	//  ,output  I_dctocore_std_ack_type core0_slice0_dctocore_std_ack      
	,output	SC_abort_type		core0_slice0_dctocore_std_ack_aborted
	,output	CORE_reqid_type		core0_slice0_dctocore_std_ack_coreid

   // dcache core 0, slice 1
	,input	logic				core0_slice1_coretodc_ld_valid
	,output	logic				core0_slice1_coretodc_ld_retry
	//  ,input   I_coretodc_ld_type      core0_slice1_coretodc_ld           
	,input	DC_ckpid_type		core0_slice1_coretodc_ld_ckpid
	,input	CORE_reqid_type		core0_slice1_coretodc_ld_coreid
	,input	CORE_lop_type		core0_slice1_coretodc_ld_lop
	,input	logic				core0_slice1_coretodc_ld_pnr
	,input	SC_pcsign_type		core0_slice1_coretodc_ld_pcsign
	,input	SC_laddr_type		core0_slice1_coretodc_ld_laddr
	,input	SC_sptbr_type		core0_slice1_coretodc_ld_sptbr
	,output	logic				core0_slice1_dctocore_ld_valid
	,input	logic				core0_slice1_dctocore_ld_retry
	//  ,output  I_coretodc_ld_type      core0_slice1_dctocore_ld           
	,output	DC_ckpid_type		core0_slice1_dctocore_ld_ckpid
	,output	CORE_reqid_type		core0_slice1_dctocore_ld_coreid
	,output	CORE_lop_type		core0_slice1_dctocore_ld_lop
	,output	logic				core0_slice1_dctocore_ld_pnr
	,output	SC_pcsign_type		core0_slice1_dctocore_ld_pcsign
	,output	SC_laddr_type		core0_slice1_dctocore_ld_laddr
	,output	SC_sptbr_type		core0_slice1_dctocore_ld_sptbr
	,input	logic				core0_slice1_coretodc_std_valid
	,output	logic				core0_slice1_coretodc_std_retry
	//  ,input   I_coretodc_std_type     core0_slice1_coretodc_std          
	,input	DC_ckpid_type		core0_slice1_coretodc_std_ckpid
	,input	CORE_reqid_type		core0_slice1_coretodc_std_coreid
	,input	CORE_mop_type		core0_slice1_coretodc_std_mop
	,input	logic				core0_slice1_coretodc_std_pnr
	,input	SC_pcsign_type		core0_slice1_coretodc_std_pcsign
	,input	SC_laddr_type		core0_slice1_coretodc_std_laddr
	,input	SC_sptbr_type		core0_slice1_coretodc_std_sptbr
	,input	SC_line_type		core0_slice1_coretodc_std_data
	,output	logic				core0_slice1_dctocore_std_ack_valid
	,input	logic				core0_slice1_dctocore_std_ack_retry
	//  ,output  I_dctocore_std_ack_type core0_slice1_dctocore_std_ack      
	,output	SC_abort_type		core0_slice1_dctocore_std_ack_aborted
	,output	CORE_reqid_type		core0_slice1_dctocore_std_ack_coreid



    // core 0 prefetcher 
	,input	logic				core0_pfgtopfe_op_valid
	,output	logic				core0_pfgtopfe_op_retry
	//  ,input  I_pfgtopfe_op_type   core0_pfgtopfe_op      
	,input	PF_delta_type		core0_pfgtopfe_op_d
	,input	PF_weigth_type		core0_pfgtopfe_op_w
	,input	SC_pcsign_type		core0_pfgtopfe_op_pcsign
	,input	SC_laddr_type		core0_pfgtopfe_op_laddr
	,input	SC_sptbr_type		core0_pfgtopfe_op_sptbr

   //******************************************
   //*  CORE 1                       *
   //******************************************//
   // icache core 1
	,input	logic				core1_coretoic_valid
	,output	logic				core1_coretoic_retry
	,input	logic				SC_laddr_type
	,output	logic				core1_ictocore_valid
	,input	logic				core1_ictocore_retry
	//  ,output I_ictocore_type      core1_ictocore              
	,output	SC_abort_type		core1_ictocore_aborted
	,output	IC_fwidth_type		core1_ictocore_data

   // dcache core 1, slice 0
	,input	logic				core1_slice0_coretodc_ld_valid
	,output	logic				core1_slice0_coretodc_ld_retry
	//  ,input   I_coretodc_ld_type      core1_slice0_coretodc_ld           
	,input	DC_ckpid_type		core1_slice0_coretodc_ld_ckpid
	,input	CORE_reqid_type		core1_slice0_coretodc_ld_coreid
	,input	CORE_lop_type		core1_slice0_coretodc_ld_lop
	,input	logic				core1_slice0_coretodc_ld_pnr
	,input	SC_pcsign_type		core1_slice0_coretodc_ld_pcsign
	,input	SC_laddr_type		core1_slice0_coretodc_ld_laddr
	,input	SC_sptbr_type		core1_slice0_coretodc_ld_sptbr
	,output	logic				core1_slice0_dctocore_ld_valid
	,input	logic				core1_slice0_dctocore_ld_retry
	//  ,output  I_coretodc_ld_type      core1_slice0_dctocore_ld           
	,output	DC_ckpid_type		core1_slice0_dctocore_ld_ckpid
	,output	CORE_reqid_type		core1_slice0_dctocore_ld_coreid
	,output	CORE_lop_type		core1_slice0_dctocore_ld_lop
	,output	logic				core1_slice0_dctocore_ld_pnr
	,output	SC_pcsign_type		core1_slice0_dctocore_ld_pcsign
	,output	SC_laddr_type		core1_slice0_dctocore_ld_laddr
	,output	SC_sptbr_type		core1_slice0_dctocore_ld_sptbr
	,input	logic				core1_slice0_coretodc_std_valid
	,output	logic				core1_slice0_coretodc_std_retry
	//  ,input   I_coretodc_std_type     core1_slice0_coretodc_std          
	,input	DC_ckpid_type		core1_slice0_coretodc_std_ckpid
	,input	CORE_reqid_type		core1_slice0_coretodc_std_coreid
	,input	CORE_mop_type		core1_slice0_coretodc_std_mop
	,input	logic				core1_slice0_coretodc_std_pnr
	,input	SC_pcsign_type		core1_slice0_coretodc_std_pcsign
	,input	SC_laddr_type		core1_slice0_coretodc_std_laddr
	,input	SC_sptbr_type		core1_slice0_coretodc_std_sptbr
	,input	SC_line_type		core1_slice0_coretodc_std_data
	,output	logic				core1_slice0_dctocore_std_ack_valid
	,input	logic				core1_slice0_dctocore_std_ack_retry
	//  ,output  I_dctocore_std_ack_type core1_slice0_dctocore_std_ack      
	,output	SC_abort_type		core1_slice0_dctocore_std_ack_aborted
	,output	CORE_reqid_type		core1_slice0_dctocore_std_ack_coreid

   // dcache core 1, slice 1
	,input	logic				core1_slice1_coretodc_ld_valid
	,output	logic				core1_slice1_coretodc_ld_retry
	//  ,input   I_coretodc_ld_type      core1_slice1_coretodc_ld           
	,input	DC_ckpid_type		core1_slice1_coretodc_ld_ckpid
	,input	CORE_reqid_type		core1_slice1_coretodc_ld_coreid
	,input	CORE_lop_type		core1_slice1_coretodc_ld_lop
	,input	logic				core1_slice1_coretodc_ld_pnr
	,input	SC_pcsign_type		core1_slice1_coretodc_ld_pcsign
	,input	SC_laddr_type		core1_slice1_coretodc_ld_laddr
	,input	SC_sptbr_type		core1_slice1_coretodc_ld_sptbr
	,output	logic				core1_slice1_dctocore_ld_valid
	,input	logic				core1_slice1_dctocore_ld_retry
	//  ,output  I_coretodc_ld_type      core1_slice1_dctocore_ld           
	,output	DC_ckpid_type		core1_slice1_dctocore_ld_ckpid
	,output	CORE_reqid_type		core1_slice1_dctocore_ld_coreid
	,output	CORE_lop_type		core1_slice1_dctocore_ld_lop
	,output	logic				core1_slice1_dctocore_ld_pnr
	,output	SC_pcsign_type		core1_slice1_dctocore_ld_pcsign
	,output	SC_laddr_type		core1_slice1_dctocore_ld_laddr
	,output	SC_sptbr_type		core1_slice1_dctocore_ld_sptbr
	,input	logic				core1_slice1_coretodc_std_valid
	,output	logic				core1_slice1_coretodc_std_retry
	//  ,input   I_coretodc_std_type     core1_slice1_coretodc_std          
	,input	DC_ckpid_type		core1_slice1_coretodc_std_ckpid
	,input	CORE_reqid_type		core1_slice1_coretodc_std_coreid
	,input	CORE_mop_type		core1_slice1_coretodc_std_mop
	,input	logic				core1_slice1_coretodc_std_pnr
	,input	SC_pcsign_type		core1_slice1_coretodc_std_pcsign
	,input	SC_laddr_type		core1_slice1_coretodc_std_laddr
	,input	SC_sptbr_type		core1_slice1_coretodc_std_sptbr
	,input	SC_line_type		core1_slice1_coretodc_std_data
	,output	logic				core1_slice1_dctocore_std_ack_valid
	,input	logic				core1_slice1_dctocore_std_ack_retry
	//  ,output  I_dctocore_std_ack_type core1_slice1_dctocore_std_ack      
	,output	SC_abort_type		core1_slice1_dctocore_std_ack_aborted
	,output	CORE_reqid_type		core1_slice1_dctocore_std_ack_coreid



    // core 1 prefetcher 
	,input	logic				core1_pfgtopfe_op_valid
	,output	logic				core1_pfgtopfe_op_retry
	//  ,input  I_pfgtopfe_op_type   core1_pfgtopfe_op      
	,input	PF_delta_type		core1_pfgtopfe_op_d
	,input	PF_weigth_type		core1_pfgtopfe_op_w
	,input	SC_pcsign_type		core1_pfgtopfe_op_pcsign
	,input	SC_laddr_type		core1_pfgtopfe_op_laddr
	,input	SC_sptbr_type		core1_pfgtopfe_op_sptbr

   //******************************************
   //*  Directory 0                    *
   //******************************************//
	,output	logic				dr0_drtomem_req_valid
	,input	logic				dr0_drtomem_req_retry
	//  ,output  I_drtomem_req_type   dr0_drtomem_req           
	,output	DR_reqid_type		dr0_drtomem_req_drid
	,output	SC_cmd_type			dr0_drtomem_req_cmd
	,output	SC_paddr_type		dr0_drtomem_req_paddr
	,input	logic				dr0_memtodr_ack_valid
	,output	logic				dr0_memtodr_ack_retry
	//  ,input   I_memtodr_ack_type   dr0_memtodr_ack           
	,input	DR_reqid_type		dr0_memtodr_ack_drid
	,input	SC_snack_type		dr0_memtodr_ack_ack
	,input	SC_line_type		dr0_memtodr_ack_line
	,output	logic				dr0_drtomem_wb_valid
	,input	logic				dr0_drtomem_wb_retry
	//  ,output  I_drtomem_wb_type    dr0_drtomem_wb            
	,output	SC_line_type		dr0_drtomem_wb_line
	,output	SC_paddr_type		dr0_drtomem_wb_paddr
	,output	logic				dr0_drtomem_pfreq_valid
	,input	logic				dr0_drtomem_pfreq_retry
	//  ,output  I_drtomem_pfreq_type dr0_drtomem_pfreq         
	,output	SC_paddr_type		dr0_drtomem_pfreq_paddr

   //******************************************
   //*  Directory 1                    *
   //******************************************//
	,output	logic				dr1_drtomem_req_valid
	,input	logic				dr1_drtomem_req_retry
	//  ,output  I_drtomem_req_type   dr1_drtomem_req           
	,output	DR_reqid_type		dr1_drtomem_req_drid
	,output	SC_cmd_type			dr1_drtomem_req_cmd
	,output	SC_paddr_type		dr1_drtomem_req_paddr
	,input	logic				dr1_memtodr_ack_valid
	,output	logic				dr1_memtodr_ack_retry
	//  ,input   I_memtodr_ack_type   dr1_memtodr_ack           
	,input	DR_reqid_type		dr1_memtodr_ack_drid
	,input	SC_snack_type		dr1_memtodr_ack_ack
	,input	SC_line_type		dr1_memtodr_ack_line
	,output	logic				dr1_drtomem_wb_valid
	,input	logic				dr1_drtomem_wb_retry
	//  ,output  I_drtomem_wb_type    dr1_drtomem_wb            
	,output	SC_line_type		dr1_drtomem_wb_line
	,output	SC_paddr_type		dr1_drtomem_wb_paddr
	,output	logic				dr1_drtomem_pfreq_valid
	,input	logic				dr1_drtomem_pfreq_retry
	//  ,output  I_drtomem_pfreq_type dr1_drtomem_pfreq         
	,output	SC_paddr_type		dr1_drtomem_pfreq_paddr

);
endmodule
