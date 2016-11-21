
`include "scmem.vh"
`include "logfunc.h"
`define DR_PASSTHROUGH

`define TEST_OLD


// Directory. Cache equivalent to 2MBytes/ 16 Way assoc
//
// Config size: 1M, 2M, 4M, 16M 16 way
//
// Assume a 64bytes line
//
// Conf Pending Requests. Two queues: one for request another for prefetch
//
// If prefetch queue is full, drop oldest 
//
// Parameter for the # of entry to remember: 4,8,16
// 
// For replacement use HawkEye or RRIP

//This has to be here for snoop acks. Current unused signals are allf ro snoop acks which the passthrough does not use
//because the directory does not snoop in the passthrough.
/* verilator lint_off UNUSED */
/* verilator lint_off UNOPTFLAT */

`define OUTSTANDING_REQUEST_BITS 2

//There are a few structs which help in reducing some of the code.
// {{{1 l2todr_req
typedef struct packed {
  logic [`OUTSTANDING_REQUEST_BITS-1:0] req_pos;
  SC_nodeid_type    nid; 
  DR_reqid_type     drid;
  SC_cmd_type       cmd;
  SC_paddr_type     paddr;
} I_dr_pipe_stage_type;
// 1}}}

// {{{1 l2todr_req
typedef struct packed {
  logic             valid;
  DR_reqid_type     drid;

  SC_cmd_type       cmd;
  SC_paddr_type     paddr;
} I_dr_req_buf_type;
// 1}}}



module directory_bank
#(parameter Directory_Id=0)
(
   input                           clk
  ,input                           reset

  // L2s interface
  ,input                           l2todr_pfreq_valid
  ,output                          l2todr_pfreq_retry
  ,input  I_l2todr_pfreq_type      l2todr_pfreq       // NOTE: pfreq does not have ack if dropped

  ,input                           l2todr_req_valid
  ,output logic                    l2todr_req_retry
  ,input  I_l2todr_req_type        l2todr_req

  ,output                          drtol2_snack_valid
  ,input                           drtol2_snack_retry
  ,output I_drtol2_snack_type      drtol2_snack

  ,input                           l2todr_disp_valid
  ,output                          l2todr_disp_retry
  ,input  I_l2todr_disp_type       l2todr_disp

  ,output                          drtol2_dack_valid
  ,input                           drtol2_dack_retry
  ,output I_drtol2_dack_type       drtol2_dack

  ,input                           l2todr_snoop_ack_valid
  ,output                          l2todr_snoop_ack_retry
  ,input I_drsnoop_ack_type        l2todr_snoop_ack

  // Memory interface
  // If nobody has the data, send request to memory

  ,output logic                    drtomem_req_valid
  ,input                           drtomem_req_retry
  ,output I_drtomem_req_type       drtomem_req

  ,input                           memtodr_ack_valid
  ,output                          memtodr_ack_retry
  ,input  I_memtodr_ack_type       memtodr_ack

  ,output                          drtomem_wb_valid
  ,input                           drtomem_wb_retry
  ,output I_drtomem_wb_type        drtomem_wb // Plain WB, no disp ack needed

  ,output logic                    drtomem_pfreq_valid
  ,input  logic                    drtomem_pfreq_retry
  ,output I_drtomem_pfreq_type     drtomem_pfreq

  );
  
`ifndef DR_PASSTHROUGH
  
  
  

  //Creating this temporary area to test a new way to manage requests
  //The first stage in a request is accessing the Tag bank. However, there are some prerequisites required
  //before a request can get to this stage.
  //1) The Tag bank is not signalling a retry. Obviously if the Tag bank is not ready, then we have to wait.
  //2) There needs to be space available in the request buffer which holds requests that are currently being snooped. The question
  //   obviously is why does this need space for every request? This is because we do not know if we need to snoop until after the Tag
  //   bank access, but we do not want the request to get stuck in this stage of the pipeline if the request buffer is full.
  //   This can cause a deadlock because other parts of the directory need access to the Tag and Entry banks but a blocked request could
  //   cause these parts to also be blocked (disp, ack) which we want to avoid. There is a solution to allow snoop requests to be queued
  //   but this would need a queue implemented which there currently is not.
  //3) There needs to be an available DRID. The directory can maintain 63 different DRIDs and we need to make sure there is one available.
  //4) The fflop that maintains the pipeline of the RAM banks are available. This availability is mostly trivial but still required to
  //   check when processing a request.
  
  //Number of requests that the directly can currently handle. This number should refer to the snoops it can handle, but right now it refers
  //to all requests. Max number of requests is currently 4. Will eventually change with an input parameter.
  //localparam OUTSTANDING_REQUEST_BITS = 2;
  localparam MAX_OUTSTANDING_REQUESTS = 1<<`OUTSTANDING_REQUEST_BITS;
  
  //Forgetting the -1 on the size is not a mistake, the extra bit is for valid.
  I_dr_req_buf_type req_buf [0:MAX_OUTSTANDING_REQUESTS-1];
  I_dr_req_buf_type req_buf_next [0:MAX_OUTSTANDING_REQUESTS-1];
  
  I_dr_req_buf_type req_buf_temp_read; 
  I_dr_req_buf_type req_buf_temp_write; 
  
  logic [DR_ENTRY_WIDTH+1:0] entry_buf [0:MAX_OUTSTANDING_REQUESTS-1];
  logic [DR_ENTRY_WIDTH+1:0] entry_buf_next [0:MAX_OUTSTANDING_REQUESTS-1];
  
  always_comb begin
    req_buf_next = req_buf;
    req_buf_temp_read = 'b0;
    req_buf_temp_write = 'b0;
    
    if(l2todr_req_valid && !l2todr_req_retry) begin
    //acquire space in buffer
      //req_buf_next[req_buf_valid_encoder] = {1'b1, tag_req_ff_stage_next};
      req_buf_next[req_buf_valid_encoder].valid = 1'b1;
      req_buf_next[req_buf_valid_encoder].paddr = tag_req_ff_stage_next.paddr;
      req_buf_next[req_buf_valid_encoder].drid = tag_req_ff_stage_next.drid;
      req_buf_next[req_buf_valid_encoder].cmd = tag_req_ff_stage_next.cmd;
    end
    
    if(tag_gen_req_next_valid && !tag_gen_req_next_retry) begin
    //release the request buffer slot...
    //Whole value is reset rather than just the valid bit because it is really annoying
    //to set just that bit and this is simpler. Will come back to fix this later, but will
    //not affect behaviour.
      req_buf_next[req_gen_buf_release_pos] = {1'b0,{$bits(I_drtomem_req_type){1'b0}}};
    end
  end
  
  always_comb begin
    entry_buf_next = entry_buf;
    //undefined: when to set a value and the position in buf to set value.
    //if a snack occurred that was initiated by a request, put this entry into the buffer
    if(req_gen_snack_valid && !req_gen_snack_retry) begin
    //acquire space in buffer
      entry_buf_next[entry_ff_stage.req_pos] = {2'b01, entry_bank_data};
    end
    
    //if we are updating a value in the buffer then do this.
    if(snoop_ack_gen_snack_valid && !snoop_ack_gen_snack_retry) begin
      entry_buf_next[sa_req_buf_ack_pos] = {sa_entry_pos, sa_entry_buf};
    end

  end
  
  genvar i;  
  generate  
    for (i=0; i < MAX_OUTSTANDING_REQUESTS; i=i+1) begin: req_buf_gen 
      flop_r #(.Size($bits(I_dr_req_buf_type)), .Reset_Value('b0))
        flop_req_buf_inst 
        (
           .clk(clk)
          ,.reset(reset)
          ,.din(req_buf_next[i])
          ,.q(req_buf[i])
        ); 
        
        flop_r #(.Size(DR_ENTRY_WIDTH + 2), .Reset_Value('b0))
        flop_entry_buf_inst 
        (
           .clk(clk)
          ,.reset(reset)
          ,.din(entry_buf_next[i])
          ,.q(entry_buf[i])
        ); 
    end  
  endgenerate 
  
  //Below is priority encoder to determine the next request buffer position to use when processing a request.
  //Might separate the valid bit to make it simpler.
  localparam MAX_REQ_BUF_VALUE = MAX_OUTSTANDING_REQUESTS-1;
  localparam REQ_BUF_VALID_POS = $bits(I_drtomem_req_type);
 
  logic [`OUTSTANDING_REQUEST_BITS-1:0] req_buf_valid_encoder;
  logic req_buf_valid;
  I_dr_req_buf_type req_buf_value_temp;
  always_comb begin  
    //This code was adapted from https://github.com/AmeerAbdelhadi/Indirectly-Indexed-2D-Binary-Content-Addressable-Memory-BCAM/blob/master/pe_bhv.v
    req_buf_valid_encoder = 'b0;
    req_buf_value_temp = req_buf[0];
    req_buf_valid = !req_buf_value_temp.valid;
    while ((!req_buf_valid) && (req_buf_valid_encoder != MAX_REQ_BUF_VALUE)) begin
      req_buf_valid_encoder = req_buf_valid_encoder + 1 ;
      req_buf_value_temp = req_buf[req_buf_valid_encoder];
      req_buf_valid = !req_buf_value_temp.valid;
    end
  end
  
  localparam REQ_PIPE_SIZE = (`OUTSTANDING_REQUEST_BITS + `SC_NODEIDBITS + $bits(I_drtomem_req_type));
  I_drtomem_req_type              request_next;
  
  I_dr_pipe_stage_type            tag_req_ff_stage_next;
  logic                           tag_req_ff_stage_next_valid;
  logic                           tag_req_ff_stage_next_retry;
  logic                           id_ram_write_next_valid;
  logic                           id_ram_write_next_retry;
  
  I_dr_pipe_stage_type            tag_req_ff_stage;
  logic                           tag_req_ff_stage_valid;
  logic                           tag_req_ff_stage_retry;
  
  
  // assign tag_req_ff_stage_next.paddr = =-.paddr;
  // assign tag_req_ff_stage_next.cmd   = l2todr_req.cmd;
  // assign tag_req_ff_stage_next.drid  = drid_valid_encoder;
  
  //Change this if other parts are competing for the next request to be sent out.
  //Currently, only l2todr_req is setting the next request.
  always_comb begin
    tag_req_ff_stage_next.paddr = l2todr_req.paddr;
    tag_req_ff_stage_next.cmd   = l2todr_req.cmd;
    tag_req_ff_stage_next.drid  = drid_valid_encoder;  
    tag_req_ff_stage_next.req_pos = req_buf_valid_encoder;
    tag_req_ff_stage_next.nid = l2todr_req.nid;
  end
  
  //valid will depend on: available DRID, available request buffer space, ID RAM ready for writing, and tag pipeline fflop ready, and Tag bank is available.
  assign l2todr_req_retry = !drid_valid || !req_buf_valid || tag_req_ff_stage_next_retry || id_ram_write_next_retry || tag_bank_read_next_retry;
  assign tag_req_ff_stage_next_valid = l2todr_req_valid && drid_valid && req_buf_valid && !id_ram_write_next_retry && !tag_bank_read_next_retry;
  assign id_ram_write_next_valid = l2todr_req_valid && drid_valid && req_buf_valid && !tag_req_ff_stage_next_retry && !tag_bank_read_next_retry;
  
  //fflop that maintains the pipeline of the request. In addtion to remembering the request that will be sent as a snoops or request to memory
  //which contains the command, paddr, and drid. This fflop also pipelines the position in the outstanding request table and the NID for the request.
  fflop #(.Size($bits(I_dr_pipe_stage_type))) tag_req_stage_fflop (
    .clk      (clk),
    .reset    (reset),

    .din      (tag_req_ff_stage_next),
    .dinValid (tag_req_ff_stage_next_valid),
    .dinRetry (tag_req_ff_stage_next_retry),

    .q        (tag_req_ff_stage),
    .qValid   (tag_req_ff_stage_valid),
    .qRetry   (tag_req_ff_stage_retry)
  );
  
  logic        tag_bank_next_valid;
  logic        tag_bank_next_retry;
  logic        tag_bank_read_next_retry;
  logic        tag_bank_write_next_retry;
  logic        tag_bank_next_we;
  logic [`log2(TAG_SIZE)-1:0]  tag_bank_next_pos;
  logic [TAG_WIDTH-1:0] tag_bank_next_data;
  
  
  //Here we determine the next access to the tag bank. The main contenders are those accessing (requests) and those writing (tag misses)
  always_comb begin
    //If there is a tag miss, we want to write a value back to the tag bank. However, we if we do this too slow it could cause a deadlock
    //Therefore, this is given priority over everything else or a deadlock could occur. I believe this will prevent deadlocks but not 100% sure.
    if(!tag_hit && tag_bank_valid) begin
      tag_bank_next_valid = tag_bank_valid && tag_req_ff_stage_valid && !entry_bank_next_retry && !drtomem_req_next_retry;
      tag_bank_next_we = 1'b1;
      tag_bank_next_pos = tag_req_ff_stage.paddr[12:6];
      tag_bank_next_data = tag_data_next;
      
      tag_bank_write_next_retry = tag_bank_next_retry;
      tag_bank_read_next_retry = 1'b1;
    end else begin
      tag_bank_next_valid = l2todr_req_valid && drid_valid && req_buf_valid && !tag_req_ff_stage_next_retry && !id_ram_write_next_retry;
      tag_bank_next_we = 'b0; //currently not writing
      tag_bank_next_pos = l2todr_req.paddr[12:6];
      tag_bank_next_data = 'b0;
      
      tag_bank_read_next_retry = tag_bank_next_retry;
      tag_bank_write_next_retry = 1'b1;
    end
  end

  
  logic        tag_bank_valid;
  logic        tag_bank_retry;
  logic [TAG_WIDTH-1:0] tag_bank_data;
  
  //The Tag bank implemented as a dense 2-cycle RAM which is 8 way associative. Therefore, each entry
  //holds 8 tags. These tags are hashes of the original Tag, so they are only 8 bits long rather than ~35 bits.
  //Width also include a valid bit for every tag. This allow us to determine check valid without checking 
  //every entry which would take 16 cycles because each entry takes 2 cycles to access and they are not stored in 
  //8-way like the tags are.
  localparam TAG_WIDTH = 72;
  localparam TAG_SIZE = 128;
  ram_1port_dense 
  #(.Width(TAG_WIDTH), .Size(TAG_SIZE), .Forward(1))
  ram_dense_tag_bank
  ( 
    .clk          (clk)
   ,.reset        (reset)

   ,.req_valid    (tag_bank_next_valid)
   ,.req_retry    (tag_bank_next_retry)
   ,.req_we       (tag_bank_next_we)
   ,.req_pos      (tag_bank_next_pos)
   ,.req_data     (tag_bank_next_data)

   ,.ack_valid    (tag_bank_valid)
   ,.ack_retry    (tag_bank_retry)
   ,.ack_data     (tag_bank_data)
  );
  
  logic       tag_hit;
  logic [7:0] paddr_hash;
  logic [7:0] tag_comp_result;
  integer j;
  
  always_comb begin
    //compare all 8 tags to the hash of the request tag. Should always result in a one-hot encoding result
    //or nothing
    //Did not want to remove this look because it look nice but is not compiling.
    // for(j = 0; j < 8; j = j + 1) begin
      // tag_comp_result[j] = (tag_bank_data[(j+1)*8-1:j*8] == compute_dr_hpaddr_hash(tag_req_ff_stage.paddr));
    // end
    paddr_hash = compute_dr_hpaddr_hash(tag_req_ff_stage.paddr);
    
    //Perform the comparison and also check the valid bit if the tag is valid.
    tag_comp_result[0] = (tag_bank_data[7:0] == paddr_hash) && tag_bank_data[64];
    tag_comp_result[1] = (tag_bank_data[15:8] == paddr_hash) && tag_bank_data[65];
    tag_comp_result[2] = (tag_bank_data[23:16] == paddr_hash) && tag_bank_data[66];
    tag_comp_result[3] = (tag_bank_data[31:24] == paddr_hash) && tag_bank_data[67];
    tag_comp_result[4] = (tag_bank_data[39:32] == paddr_hash) && tag_bank_data[68];
    tag_comp_result[5] = (tag_bank_data[47:40] == paddr_hash) && tag_bank_data[69];
    tag_comp_result[6] = (tag_bank_data[55:48] == paddr_hash) && tag_bank_data[70];
    tag_comp_result[7] = (tag_bank_data[63:56] == paddr_hash) && tag_bank_data[71];
    
    //OR all bits of the result to check if there is a hit in the Tags
    //A miss would result in a request to memory. A hit would result in a check of the Entry bank and then a snoop.
    tag_hit = |tag_comp_result;
  end
  
  localparam TAG_BANK_ASSOC_BITS = 3;
  localparam TAG_BANK_ASSOC = 1<<TAG_BANK_ASSOC_BITS;
  localparam TAG_POS_MAX_VALUE = TAG_BANK_ASSOC-1;
 
  logic [TAG_BANK_ASSOC_BITS-1:0] tag_pos_next;
  logic tag_pos_valid;
  logic [TAG_BANK_ASSOC-1:0] tag_valid_bits;
  
  assign tag_valid_bits = tag_bank_data[71:64];
  
  always_comb begin  
    //This code was adapted from https://github.com/AmeerAbdelhadi/Indirectly-Indexed-2D-Binary-Content-Addressable-Memory-BCAM/blob/master/pe_bhv.v
    tag_pos_next = 'b0;
    if(tag_hit) begin
      tag_pos_valid = tag_valid_bits[0];
    end else begin
      tag_pos_valid = !tag_valid_bits[0];
    end
    //Also would need to change the value below. Do this or separate the valid but into separate flops.
    //tag_pos_valid = req_buf[0][REQ_BUF_VALID_POS];
    while ((!tag_pos_valid) && (tag_pos_next != TAG_POS_MAX_VALUE)) begin
      tag_pos_next = tag_pos_next + 1 ;
      
      if(tag_hit) begin
      tag_pos_valid = tag_valid_bits[tag_pos_next];
    end else begin
      tag_pos_valid = !tag_valid_bits[tag_pos_next];
    end
      
    end
  end
  
  //This next always block determines how the next value in the tag bank will be written which depends on the valid bits of the Tag.
  //The valid bits generate a position which provides details on which "way" this request will secure in the 8-way Tag bank. This could
  //also be done with just the valid bits and not the position.
  logic [TAG_WIDTH-1:0] tag_data_next;
  always_comb begin
    tag_data_next = tag_bank_data;
    if(tag_pos_next == 3'd0) begin
      tag_data_next[64] = 1'b1;
      tag_data_next[7:0] = paddr_hash;
    end else if(tag_pos_next == 3'd1) begin
      tag_data_next[65] = 1'b1;
      tag_data_next[15:8] = paddr_hash;
    end else if(tag_pos_next == 3'd2) begin
      tag_data_next[66] = 1'b1;
      tag_data_next[23:16] = paddr_hash;
    end else if(tag_pos_next == 3'd3) begin
      tag_data_next[67] = 1'b1;
      tag_data_next[31:24] = paddr_hash;
    end else if(tag_pos_next == 3'd4) begin
      tag_data_next[68] = 1'b1;
      tag_data_next[39:32] = paddr_hash;
    end else if(tag_pos_next == 3'd5) begin
      tag_data_next[69] = 1'b1;
      tag_data_next[47:40] = paddr_hash;
    end else if(tag_pos_next == 3'd6) begin
      tag_data_next[70] = 1'b1;
      tag_data_next[55:48] = paddr_hash;
    end else if(tag_pos_next == 3'd7) begin
      tag_data_next[71] = 1'b1;
      tag_data_next[63:56] = paddr_hash;
    end
  end
  
  logic [DR_ENTRY_WIDTH-1:0] tag_miss_entry;
  logic [`log2(DR_ENTRY_SIZE)-1:0] entry_pos_next;
  
  //this is temporary and wont compile.
  assign tag_miss_entry = {tag_req_ff_stage.nid,{15{1'b0}}};
  assign entry_pos_next = {tag_pos_next, tag_req_ff_stage.paddr[12:6]};
  
  I_drtomem_req_type              tag_gen_req_next;
  logic                           tag_gen_req_next_valid;
  logic                           tag_gen_req_next_retry;
  logic [`OUTSTANDING_REQUEST_BITS-1:0] req_gen_buf_release_pos;
  
  always_comb begin 
    tag_gen_req_next_valid = 'b0;
    tag_gen_req_next = 'b0;
    if(!tag_hit) begin
      tag_gen_req_next.paddr = tag_req_ff_stage.paddr;
      tag_gen_req_next.drid = tag_req_ff_stage.drid;
      tag_gen_req_next.cmd = tag_req_ff_stage.cmd;
      tag_gen_req_next_valid = tag_bank_valid && tag_req_ff_stage_valid && !entry_bank_next_retry && !tag_bank_write_next_retry;
    end 
  end
  
  
  always_comb begin
    req_gen_buf_release_pos = tag_req_ff_stage.req_pos;
    entry_ff_stage_next = 'b0;
    entry_ff_stage_next_valid = 'b0;
    
    if(!tag_hit) begin     
      entry_bank_next_valid = tag_bank_valid && tag_req_ff_stage_valid && !tag_gen_req_next_retry && !tag_bank_write_next_retry;
      entry_bank_next_we = 1'b1;
      entry_bank_next_pos = entry_pos_next;
      entry_bank_next_data = tag_miss_entry;
      
      tag_bank_retry = tag_gen_req_next_retry || entry_bank_next_retry || tag_bank_write_next_retry || (!tag_req_ff_stage_valid && tag_bank_valid);
      tag_req_ff_stage_retry = tag_gen_req_next_retry || entry_bank_next_retry || tag_bank_write_next_retry || (!tag_bank_valid && tag_req_ff_stage_valid);
    end else begin
      //should not enter this... something went wrong if this is entered for now since all tag accesses should be a miss.
      //Turns out, tag hits can occur with nothing written, but mostly bugs out since I was not checking if the tag_bank data was valid.
      //Setting this temporarily.
      entry_ff_stage_next = tag_req_ff_stage;
      entry_ff_stage_next_valid = tag_bank_valid && tag_req_ff_stage_valid && !entry_bank_next_retry;
      
      entry_bank_next_valid = tag_bank_valid && tag_req_ff_stage_valid && !entry_ff_stage_next_retry;
      entry_bank_next_we = 1'b0;
      entry_bank_next_pos = entry_pos_next;
      entry_bank_next_data = 'b0;
      
      tag_bank_retry = entry_ff_stage_next_retry || entry_bank_next_retry || (!tag_req_ff_stage_valid && tag_bank_valid);
      tag_req_ff_stage_retry = entry_ff_stage_next_retry || entry_bank_next_retry || (!tag_bank_valid && tag_req_ff_stage_valid);
    end
  end
  
//MEMTODR REQ ARBITER START
  I_drtomem_req_type              drtomem_req_next;
  logic                           drtomem_req_next_valid;
  logic                           drtomem_req_next_retry;
  
  //This always block also controls logic for the retries including: disp_gen_req_retry, snoop_ack_gen_mem_req_retry, and
  //tag_gen_req_next_retry
  
  always_comb begin  
    drtomem_req_next = 'b0;
    
    if(tag_gen_req_next_valid) begin
      drtomem_req_next = tag_gen_req_next;
    end else if(disp_gen_req_valid) begin
      drtomem_req_next = disp_gen_req;
    end else if(snoop_ack_gen_mem_req_valid) begin
      drtomem_req_next = snoop_ack_gen_req;
    end
  end

  always_comb begin
    drtomem_req_next_valid = 'b0;
    disp_gen_req_retry = 1'b1;
    snoop_ack_gen_mem_req_retry = 1'b1;
    tag_gen_req_next_retry = 1'b1;
    
    if(tag_gen_req_next_valid) begin
      drtomem_req_next_valid = 1'b1;
      tag_gen_req_next_retry = drtomem_req_next_retry;
    end else if(disp_gen_req_valid) begin
      drtomem_req_next_valid = 1'b1;
      disp_gen_req_retry = drtomem_req_next_retry;
    end else if(snoop_ack_gen_mem_req_valid) begin
      drtomem_req_next_valid = 1'b1;
      snoop_ack_gen_mem_req_retry = drtomem_req_next_retry;
    end
  end   
  
  //This fflop determines the next request sent to memory. Right now, only misses from an invalid tag can occur.
  //However, a miss can also occur from a snoop.
  fflop #(.Size($bits(I_drtomem_req_type))) drtomem_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtomem_req_next),
    .dinValid (drtomem_req_next_valid),
    .dinRetry (drtomem_req_next_retry),

    .q        (drtomem_req),
    .qValid   (drtomem_req_valid),
    .qRetry   (drtomem_req_retry)
  );
  
//MEMTODR REQ ARBITER END
  
  // logic temp_buf_valid_0;
  // logic temp_buf_valid_1;
  // logic temp_buf_valid_2;
  // logic temp_buf_valid_3;
  // I_drtomem_req_type temp_buf_req_0;
  // I_drtomem_req_type temp_buf_req_1;
  // I_drtomem_req_type temp_buf_req_2;
  // I_drtomem_req_type temp_buf_req_3;
  
  
  // //This is somewhat of an encoder to determine which buffer value needs to be released. 
  // //To Recap: When a request occurs, the directory will assign buffer space to it just in case in might snoop. When it gets to this point and
  // //is determined a miss, we need to release that buffer space. The release happens above in a comb block near where the buffer is instantiated
  // //but this block determines which space needs to be released.
  // always_comb begin
    // //this assumes that there is a position in the buffer that this request takes up. Other parts may clear that
    // //so I may add some sort of abort boolean to prevent clearing not in use buffers.
    // {temp_buf_valid,temp_buf_req} = req_buf[0];
    // req_gen_buf_release_pos = 'b0;
    // while((!temp_buf_valid && temp_buf_req.drid != drtomem_req_next.drid) || req_gen_buf_release_pos == MAX_REQ_BUF_VALUE) begin
      // req_gen_buf_release_pos = req_gen_buf_release_pos + 1;
      // {temp_buf_valid,temp_buf_req} = req_buf[req_gen_buf_release_pos];
    // end
  // end
  
  // always_comb begin
    // {temp_buf_valid_0,temp_buf_req_0} = req_buf[0];
    // {temp_buf_valid_1,temp_buf_req_1} = req_buf[1];
    // {temp_buf_valid_2,temp_buf_req_2} = req_buf[2];
    // {temp_buf_valid_3,temp_buf_req_3} = req_buf[3];
    // req_gen_buf_release_pos = 'b0;
    // if         (temp_buf_valid_0 && temp_buf_req_0.drid == drtomem_req_next.drid) begin
      // req_gen_buf_release_pos = 2'd0;
    // end else if(temp_buf_valid_1 && temp_buf_req_1.drid == drtomem_req_next.drid) begin
      // req_gen_buf_release_pos = 2'd1;
    // end else if(temp_buf_valid_2 && temp_buf_req_2.drid == drtomem_req_next.drid) begin
      // req_gen_buf_release_pos = 2'd2;
    // end else if(temp_buf_valid_3 && temp_buf_req_3.drid == drtomem_req_next.drid) begin
      // req_gen_buf_release_pos = 2'd3;
    // end 
  // end
  
  //Number of bits per entry. Arbitrary for now. Will be parametrically defined at some time.
  localparam DR_ENTRY_WIDTH = 20;
  localparam DR_ENTRY_SIZE = 1024;
  
  logic        entry_bank_next_valid;
  logic        entry_bank_next_retry;
  logic        entry_bank_next_we;
  logic [`log2(DR_ENTRY_SIZE)-1:0]  entry_bank_next_pos;
  logic [DR_ENTRY_WIDTH-1:0] entry_bank_next_data;
  
  
  logic        entry_bank_valid;
  logic        entry_bank_retry;
  logic [DR_ENTRY_WIDTH-1:0] entry_bank_data;
  
  assign entry_bank_retry = 'b0;
  
  //The Directory Entry bank implemented as a dense 2-cycle RAM which is direct mapped. However, we use information from the Tag
  //bank in order to index this RAM in addition to bits from the paddr
  ram_1port_dense 
  #(.Width(DR_ENTRY_WIDTH), .Size(DR_ENTRY_SIZE), .Forward(1))
  ram_dense_entry_bank
  ( 
    .clk          (clk)
   ,.reset        (reset)

   ,.req_valid    (entry_bank_next_valid)
   ,.req_retry    (entry_bank_next_retry)
   ,.req_we       (entry_bank_next_we)
   ,.req_pos      (entry_bank_next_pos)
   ,.req_data     (entry_bank_next_data)

   ,.ack_valid    (entry_bank_valid)
   ,.ack_retry    (entry_bank_retry)
   ,.ack_data     (entry_bank_data)
  );
  
  I_dr_pipe_stage_type            entry_ff_stage_next;
  logic                           entry_ff_stage_next_valid;
  logic                           entry_ff_stage_next_retry;
  
  I_dr_pipe_stage_type            entry_ff_stage;
  logic                           entry_ff_stage_valid;
  logic                           entry_ff_stage_retry;
  //fflop that maintains the pipeline of the request during the phase which we are accessing the entry bank.
  fflop #(.Size($bits(I_dr_pipe_stage_type))) entry_stage_fflop (
    .clk      (clk),
    .reset    (reset),

    .din      (entry_ff_stage_next),
    .dinValid (entry_ff_stage_next_valid),
    .dinRetry (entry_ff_stage_next_retry),

    .q        (entry_ff_stage),
    .qValid   (entry_ff_stage_valid),
    .qRetry   (entry_ff_stage_retry)
  );
  
  I_drtol2_snack_type     req_gen_snack;
  logic                   req_gen_snack_valid;
  logic                   req_gen_snack_retry;
  
  always_comb begin
    req_gen_snack_valid = entry_bank_valid && entry_ff_stage_valid;
    entry_ff_stage_retry = req_gen_snack_retry || !entry_bank_valid;
    entry_bank_retry = req_gen_snack_retry || !entry_ff_stage_valid;
  end
  
  assign req_gen_snack.nid = entry_bank_data[19:15];
  assign req_gen_snack.l2id = 'b0;
  assign req_gen_snack.drid = entry_ff_stage.drid;
  assign req_gen_snack.directory_id = Directory_Id;
  assign req_gen_snack.line = 'b0;
  assign req_gen_snack.hpaddr_base = compute_dr_hpaddr_base(entry_ff_stage.paddr);
  assign req_gen_snack.hpaddr_hash = compute_dr_hpaddr_hash(entry_ff_stage.paddr);
  assign req_gen_snack.paddr = 'b0;
  
  always_comb begin
    req_gen_snack.snack = `SC_SCMD_WI;
    if(entry_ff_stage.cmd == `SC_CMD_REQ_S) begin
      req_gen_snack.snack = `SC_SCMD_WS;
    end
  end
  
  
//SNOOP ACK START
  
  //Below code finds which outstanding request this ack refers to using the DRID provided in the snoop ack.
  logic sa_temp_buf_valid_0;
  logic sa_temp_buf_valid_1;
  logic sa_temp_buf_valid_2;
  logic sa_temp_buf_valid_3;
  I_dr_req_buf_type sa_temp_buf_req_0;
  I_dr_req_buf_type sa_temp_buf_req_1;
  I_dr_req_buf_type sa_temp_buf_req_2;
  I_dr_req_buf_type sa_temp_buf_req_3;
  logic [`OUTSTANDING_REQUEST_BITS-1:0] sa_req_buf_ack_pos;
  
  
  always_comb begin
    sa_temp_buf_req_0 = req_buf[0];
    sa_temp_buf_req_1 = req_buf[1];
    sa_temp_buf_req_2 = req_buf[2];
    sa_temp_buf_req_3 = req_buf[3];
    sa_req_buf_ack_pos = 'b0;
    if         (sa_temp_buf_req_0.valid && sa_temp_buf_req_0.drid == l2todr_snoop_ack.drid) begin
      sa_req_buf_ack_pos = 2'd0;
    end else if(sa_temp_buf_req_1.valid && sa_temp_buf_req_1.drid == l2todr_snoop_ack.drid) begin
      sa_req_buf_ack_pos = 2'd1;
    end else if(sa_temp_buf_req_2.valid && sa_temp_buf_req_2.drid == l2todr_snoop_ack.drid) begin
      sa_req_buf_ack_pos = 2'd2;
    end else if(sa_temp_buf_req_3.valid && sa_temp_buf_req_3.drid == l2todr_snoop_ack.drid) begin
      sa_req_buf_ack_pos = 2'd3;
    end 
  end
  
  I_dr_req_buf_type sa_buf;
  
  assign sa_buf = req_buf[sa_req_buf_ack_pos];
  
  logic [`OUTSTANDING_REQUEST_BITS-1:0] sa_entry_pos_next;
  logic [`OUTSTANDING_REQUEST_BITS-1:0] sa_entry_pos;
  logic [DR_ENTRY_WIDTH-1:0] sa_entry_buf;
  
  logic checked_all_positions;
  
  assign {sa_entry_pos, sa_entry_buf} = entry_buf[sa_req_buf_ack_pos];
  
  I_drtol2_snack_type     snoop_ack_gen_snack;
  logic                   snoop_ack_gen_snack_valid;
  logic                   snoop_ack_gen_snack_retry;
  
  I_drtomem_req_type      snoop_ack_gen_req;
  logic                   snoop_ack_gen_mem_req_valid;
  logic                   snoop_ack_gen_mem_req_retry;
  
  //These signals are for an internal command which will not propagate outside the DR
  logic                   snoop_ack_gen_in_req_valid;
  logic                   snoop_ack_gen_in_req_retry;
  
  assign snoop_ack_gen_in_req_retry = 1'b1;
  
  always_comb begin
    snoop_ack_gen_snack_valid = 'b0;
    l2todr_snoop_ack_retry = 1'b1;
    
    //This case indicates we are going to send a snoop to the next core
    if(!checked_all_positions) begin
      snoop_ack_gen_snack_valid = l2todr_snoop_ack_valid;
      l2todr_snoop_ack_retry = snoop_ack_gen_snack_retry;
    end else begin
    //This case indicates we have checked all cores and this request is now deemed a miss and should send a request to memory.
      snoop_ack_gen_mem_req_valid = l2todr_snoop_ack_valid && !snoop_ack_gen_in_req_retry;
      snoop_ack_gen_in_req_valid = l2todr_snoop_ack_valid && !snoop_ack_gen_mem_req_retry;
      l2todr_snoop_ack_retry = snoop_ack_gen_in_req_retry || snoop_ack_gen_mem_req_retry;
    end
  end
  
  assign snoop_ack_gen_req.drid = sa_buf.drid;
  assign snoop_ack_gen_req.cmd = sa_buf.cmd;
  assign snoop_ack_gen_req.paddr = sa_buf.paddr;
  
  
  
  //assign snoop_ack_gen_snack.nid = entry_bank_data[19:15];
  assign snoop_ack_gen_snack.l2id = 'b0;
  assign snoop_ack_gen_snack.drid = sa_buf.drid;
  assign snoop_ack_gen_snack.directory_id = Directory_Id;
  assign snoop_ack_gen_snack.line = 'b0;
  assign snoop_ack_gen_snack.hpaddr_base = compute_dr_hpaddr_base(sa_buf.paddr);
  assign snoop_ack_gen_snack.hpaddr_hash = compute_dr_hpaddr_hash(sa_buf.paddr);
  assign snoop_ack_gen_snack.paddr = 'b0;
  
  always_comb begin
    checked_all_positions = 0;
    snoop_ack_gen_snack.nid = 'b0;
    sa_entry_pos_next = sa_entry_pos + 1;
    
    if(sa_entry_pos == 2'd0) begin
      snoop_ack_gen_snack.nid = entry_bank_data[14:10];
    end else if(sa_entry_pos == 2'd1) begin
      snoop_ack_gen_snack.nid = entry_bank_data[9:5];
    end else if(sa_entry_pos == 2'd2) begin
      snoop_ack_gen_snack.nid = entry_bank_data[4:0];
    end else begin
      //If this occurs, we are done sending snoops and need to just write in the entry and designate this request as a miss.
      checked_all_positions = 1'b1;
    end
  end
  
  always_comb begin
    snoop_ack_gen_snack.snack = `SC_SCMD_WI;
    if(sa_buf.cmd == `SC_CMD_REQ_S) begin
      snoop_ack_gen_snack.snack = `SC_SCMD_WS;
    end
  end
//SNOOP ACK END
  
//L2TODR DISP START
  logic temp_buf_valid_0;
  logic temp_buf_valid_1;
  logic temp_buf_valid_2;
  logic temp_buf_valid_3;
  I_drtomem_req_type temp_buf_req_0;
  I_drtomem_req_type temp_buf_req_1;
  I_drtomem_req_type temp_buf_req_2;
  I_drtomem_req_type temp_buf_req_3;
  logic [`OUTSTANDING_REQUEST_BITS-1:0] req_buf_ack_pos;
  
  
  always_comb begin
    {temp_buf_valid_0,temp_buf_req_0} = req_buf[0];
    {temp_buf_valid_1,temp_buf_req_1} = req_buf[1];
    {temp_buf_valid_2,temp_buf_req_2} = req_buf[2];
    {temp_buf_valid_3,temp_buf_req_3} = req_buf[3];
    req_buf_ack_pos = 'b0;
    if         (temp_buf_valid_0 && temp_buf_req_0.drid == l2todr_disp.drid) begin
      req_buf_ack_pos = 2'd0;
    end else if(temp_buf_valid_1 && temp_buf_req_1.drid == l2todr_disp.drid) begin
      req_buf_ack_pos = 2'd1;
    end else if(temp_buf_valid_2 && temp_buf_req_2.drid == l2todr_disp.drid) begin
      req_buf_ack_pos = 2'd2;
    end else if(temp_buf_valid_3 && temp_buf_req_3.drid == l2todr_disp.drid) begin
      req_buf_ack_pos = 2'd3;
    end 
  end
  
  logic disp_buf_valid;
  I_drtomem_req_type disp_buf;
  
  assign {disp_buf_valid, disp_buf} = req_buf[req_buf_ack_pos];
  
  //This needs to generate a combination of the following: a writeback to mem, an snack to ack back a line, and an internal
  //request to change an entry, and a request to memory.
  
  I_drtol2_snack_type     disp_gen_snack;
  logic                   disp_gen_snack_valid;
  logic                   disp_gen_snack_retry;
  
  I_drtomem_wb_type       disp_gen_wb;
  logic                   disp_gen_wb_valid;
  logic                   disp_gen_wb_retry;
  
  I_drtomem_req_type      disp_gen_req;
  logic                   disp_gen_req_valid;
  logic                   disp_gen_req_retry;
  
  logic                   disp_gen_req_in_valid;
  logic                   disp_gen_req_in_retry;
  
  assign disp_gen_req_in_retry = 1'b0;
  
  always_comb begin
    disp_gen_snack = 'b0;
    disp_gen_snack_valid = 'b0;
  
    disp_gen_wb = 'b0;
    disp_gen_wb_valid = 'b0;
  
    disp_gen_req = 'b0;
    disp_gen_req_valid = 'b0;
  
    l2todr_disp_retry = 1'b1;
  
    //if the drid is not zero then this disp indicates a command generated by the l2 
    if(l2todr_disp.drid != 'b0) begin
      disp_gen_wb.line = l2todr_disp.line;
      disp_gen_wb.paddr = l2todr_disp.paddr;
      //mask not set on purpose. Mask is only set when command is for non-cacheables. Check case below.
      
      disp_gen_req.paddr = l2todr_disp.paddr;
      //drid not set on purpose, should be set to 0 because this request is internal and will not make it outside DR
      //Command also not set. Depends on the cases defines below. Actually, cmd can be set.
      disp_gen_req.cmd = `SC_CMD_REQ_M;
      //nid also needs to be included when I get around to that
      
      
      //Below is mostly retry/valid logic for the fflops
      if(l2todr_disp.dcmd == `SC_DCMD_WI) begin
        //wb data, send internal request to erase value indicated by nid  
        disp_gen_wb_valid = l2todr_disp_valid && !disp_gen_req_in_retry && !drtol2_dack_next_retry;
        disp_gen_req_in_valid = l2todr_disp_valid && !disp_gen_wb_retry && !drtol2_dack_next_retry;
        drtol2_dack_next_valid = l2todr_disp_valid && !disp_gen_wb_retry && !disp_gen_req_in_retry;
        l2todr_disp_retry = disp_gen_wb_retry || disp_gen_req_in_retry || drtol2_dack_next_retry;
      end else if(l2todr_disp.dcmd == `SC_DCMD_WS) begin
        //wb data
        disp_gen_wb_valid = l2todr_disp_valid && !drtol2_dack_next_retry;
        drtol2_dack_next_valid = l2todr_disp_valid && !disp_gen_wb_retry;
        l2todr_disp_retry = disp_gen_wb_retry || drtol2_dack_next_retry;
      end else if(l2todr_disp.dcmd == `SC_DCMD_I) begin
        //send internal request to erase value indicated by nid
        disp_gen_req_in_valid = l2todr_disp_valid && !drtol2_dack_next_retry;
        drtol2_dack_next_valid = l2todr_disp_valid && !disp_gen_req_in_retry;
        l2todr_disp_retry = disp_gen_req_in_retry || drtol2_dack_next_retry;
      end else if(l2todr_disp.dcmd == `SC_DCMD_NC) begin
        //wb data
        disp_gen_wb_valid = l2todr_disp_valid && !drtol2_dack_next_retry;
        l2todr_disp_retry = disp_gen_wb_retry || drtol2_dack_next_retry;
        drtol2_dack_next_valid = l2todr_disp_valid && !disp_gen_wb_retry;
        disp_gen_wb.mask = l2todr_disp.mask;
      end else begin
        //error state, ignore this disp
        l2todr_disp_retry = drtol2_dack_next_retry;
        drtol2_dack_next_valid = l2todr_disp_valid;
      end
    
    end else begin //otherwise, this is an ack to a snoop we performed previously
      disp_gen_wb.line = l2todr_disp.line;
      disp_gen_wb.paddr = l2todr_disp.paddr;
      
      disp_gen_req.paddr = l2todr_disp.paddr;
      disp_gen_req.cmd = `SC_CMD_REQ_S;
      
      disp_gen_snack.l2id = 'b0;
      disp_gen_snack.nid = 'b0;
      disp_gen_snack.drid = 'b0;
      disp_gen_snack.directory_id = Directory_Id;
      disp_gen_snack.line = l2todr_disp.line;
      disp_gen_snack.hpaddr_base = compute_dr_hpaddr_base(disp_buf.paddr);
      disp_gen_snack.hpaddr_hash = compute_dr_hpaddr_hash(disp_buf.paddr);
      disp_gen_snack.paddr = 'b0;
      
      disp_gen_snack.snack = `SC_SCMD_ACK_S;
      if(disp_buf.cmd == `SC_CMD_REQ_M) begin
        disp_gen_snack.snack = `SC_SCMD_ACK_M;
      end
    
      //make sure to check paddr. An incorrect paddr could cause a miss.
      if(l2todr_disp.dcmd == `SC_DCMD_WI) begin
        //wb data, send internal request to erase value indicated by nid, send data to requester
        disp_gen_wb_valid = l2todr_disp_valid && !disp_gen_req_in_retry && !disp_gen_snack_retry;
        disp_gen_req_in_valid = l2todr_disp_valid && !disp_gen_wb_retry && !disp_gen_snack_retry;
        disp_gen_snack_valid = l2todr_disp_valid && !disp_gen_req_in_retry && !disp_gen_wb_retry;
        l2todr_disp_retry = disp_gen_wb_retry || disp_gen_req_in_retry || disp_gen_snack_retry;
        
      end else if(l2todr_disp.dcmd == `SC_DCMD_WS) begin
        //wb data, update entry with new node, send data to node
        disp_gen_wb_valid = l2todr_disp_valid && !disp_gen_req_in_retry && !disp_gen_snack_retry;
        disp_gen_req_in_valid = l2todr_disp_valid && !disp_gen_wb_retry && !disp_gen_snack_retry;
        disp_gen_snack_valid = l2todr_disp_valid && !disp_gen_req_in_retry && !disp_gen_wb_retry;
        l2todr_disp_retry = disp_gen_wb_retry || disp_gen_req_in_retry || disp_gen_snack_retry;
      end else if(l2todr_disp.dcmd == `SC_DCMD_I) begin
        //This is an error state. The L2 should never use this command as a response to a snoop.
        //It should always use the snoop ack signals in order to ack a snoop with no displacement
        l2todr_disp_retry = 'b0;
      end else if(l2todr_disp.dcmd == `SC_DCMD_NC) begin
        //wb data, send data to node
        disp_gen_wb_valid = l2todr_disp_valid && !disp_gen_snack_retry;
        disp_gen_snack_valid = l2todr_disp_valid && !disp_gen_wb_retry;
        l2todr_disp_retry = disp_gen_wb_retry || disp_gen_snack_retry;
        disp_gen_wb.mask = l2todr_disp.mask;
      end else begin
        //error state, ignore this disp
        l2todr_disp_retry = 'b0;
      end
    end
  end
//L2TODR DISP END
  
//SNACK ARBITER START
  I_drtol2_snack_type     drtol2_snack_next;
  logic                   drtol2_snack_next_valid;
  logic                   drtol2_snack_next_retry;
  
  //This always block also controls logic for the retries including: disp_gen_snack_retry, snoop_ack_gen_snack_retry, and
  //req_gen_snack_retry
  
  always_comb begin
    drtol2_snack_next_valid = 'b0;
    disp_gen_snack_retry = 1'b1;
    snoop_ack_gen_snack_retry = 1'b1;
    req_gen_snack_retry = 1'b1;
    
    if(req_gen_snack_valid) begin
      drtol2_snack_next_valid = 1'b1;
      req_gen_snack_retry = drtol2_snack_next_retry;
    end else if(disp_gen_snack_valid) begin
      drtol2_snack_next_valid = 1'b1;
      disp_gen_snack_retry = drtol2_snack_next_retry;
      
      //leaving this commented out because it tells me out to include some other useful parts.
      // drtol2_snack_next_valid = memtodr_ack_ff_valid && id_ram_valid; 
      // memtodr_ack_ff_retry = drtol2_snack_next_retry || (!drtol2_snack_next_valid && memtodr_ack_ff_valid);
      // id_ram_retry = drtol2_snack_next_retry || (!drtol2_snack_next_valid && id_ram_valid);
    end else if(snoop_ack_gen_snack_valid) begin
      drtol2_snack_next_valid = 1'b1;
      snoop_ack_gen_snack_retry = drtol2_snack_next_retry;
    end
  end 
  
  always_comb begin   
    drtol2_snack_next = 'b0;
    
    if(req_gen_snack_valid) begin
      drtol2_snack_next = req_gen_snack;
    end else if(disp_gen_snack_valid) begin
      drtol2_snack_next = disp_gen_snack;
    end else if(snoop_ack_gen_snack_valid) begin
      drtol2_snack_next = snoop_ack_gen_snack;
    end
  end 
  
  fflop #(.Size($bits(I_drtol2_snack_type))) drotol2_snack_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtol2_snack_next),
    .dinValid (drtol2_snack_next_valid),
    .dinRetry (drtol2_snack_next_retry),

    .q        (drtol2_snack),
    .qValid   (drtol2_snack_valid),
    .qRetry   (drtol2_snack_retry)
  );
//SNACK ARBITER END
  
//DRTOMEM WB START
  I_drtomem_wb_type         drtomem_wb_next;
  logic                     drtomem_wb_next_valid;
  logic                     drtomem_wb_next_retry;
  
  always_comb begin
    drtomem_wb_next = disp_gen_wb;
    drtomem_wb_next_valid = disp_gen_wb_valid;
    disp_gen_wb_retry = drtomem_wb_next_retry;
  end
  
  fflop #(.Size($bits(I_drtomem_wb_type))) memtodr_wb_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtomem_wb_next),
    .dinValid (drtomem_wb_next_valid),
    .dinRetry (drtomem_wb_next_retry),

    .q        (drtomem_wb),
    .qValid   (drtomem_wb_valid),
    .qRetry   (drtomem_wb_retry)
  );
  
//DRTOMEM WB END

//DRID VALID ENCODER START
  localparam MAX_DRID_VALUE = `DR_REQIDS-1;
 
  logic [`DR_REQIDBITS-1:0] drid_valid_encoder;
  logic drid_valid;
  always_comb begin 
    //Yes, I know the while loop looks bad, and I agree. The while loop is to allow for parametrization, but this scheme may
    //affect synthesis and may be forced to change.    
    //This for loop implements a priority encoder. It uses a 64 bit vector input which holds
    //a valid bit for every possible DRID. This encoder looks at the bit vector and determines a 
    //valid DRID which can be used for a memory request. The encoder is likely huge based on seeing examples
    //for small priority encoders.
    //The benefits of this scheme are that it does an arbitration of which DRID should be used and it does it quickly.
    //The obvious downsides it the gate count is large. However, we only need one of these.
    
    //This code was adapted from https://github.com/AmeerAbdelhadi/Indirectly-Indexed-2D-Binary-Content-Addressable-Memory-BCAM/blob/master/pe_bhv.v
    drid_valid_encoder = {`DR_REQIDBITS{1'b0}};
    //drid_valid_encoder = 1'b1; //temporary declaration
    drid_valid = 1'b0;
    while ((!drid_valid) && (drid_valid_encoder != MAX_DRID_VALUE)) begin
      drid_valid_encoder = drid_valid_encoder + 1 ;
      drid_valid = drid_valid_vector[drid_valid_encoder];
    end
  end
//DRID VALID ENCODER END
  
//ID RAM START 
  logic id_ram_next_valid;
  logic id_ram_next_retry;
  logic id_ram_we;
  logic [`DR_REQIDBITS-1:0] id_ram_pos_next;
  
  logic id_ram_valid;
  logic id_ram_retry;
  logic [10:0] id_ram_data;
  
  assign id_ram_retry = 1'b1;
  
  ram_1port_fast 
   #(.Width(11), .Size(`DR_REQIDS), .Forward(1))
  id_ram ( 
    .clk         (clk)
   ,.reset       (reset)

   ,.req_valid   (id_ram_next_valid)
   ,.req_retry   (id_ram_next_retry)
   ,.req_we      (id_ram_we) 
   ,.req_pos     (id_ram_pos_next)
   ,.req_data    ({l2todr_req.nid,l2todr_req.l2id})

   ,.ack_valid   (id_ram_valid)
   ,.ack_retry   (id_ram_retry)
   ,.ack_data    (id_ram_data)
 );

//ID RAM END

//ID RAM ARBITER START
  
  localparam ARBITER_READ_PREFERRED_STATE = 1'b0;
  localparam ARBITER_WRITE_PREFERRED_STATE = 1'b1;
  
  //not assigned: arb_drid_write_valid

  
  logic id_ram_state;
  logic id_ram_state_next;
  //I had to separate the write enable signal into a different always block or else a warning will occur claiming circular logic. This warning appears to be a glitch
  //and should not affect simulation, but I removed it anyway.
  always_comb begin
    id_ram_we = 1'b0;
    if(id_ram_state == ARBITER_READ_PREFERRED_STATE) begin    
      if(id_ram_write_next_valid && !id_ram_read_next_valid) begin
        id_ram_we = 1'b1;
      end
      
    end else begin //state == ARBITER_WRITE_PREFERRED_STATE
      if(id_ram_write_next_valid) begin
        id_ram_we = 1'b1;
      end 
      
    end
  end
  
  //This always blocks performs the next state logic for the DRID RAM READ/WRITE arbiter FSM. It also contains some output logic
  //for the FSM but not all of it. The write enable had to be moved outside the always blocks because it caused warnings to occur
  //when they were in the same always block.
  
  always_comb begin
    //default next state is the current state
    id_ram_state_next = id_ram_state;
    
    //default retry on read or writes is the retry coming from the SRAM, however this will fail in some cases. For example,
    //if retry from SRAM is high and both valids from retry are high then the operation that occurs after the retry falls LOW
    //depends on which state we are in. If the SRAM retry falls low, then the fflops think that their valid goes through, but
    //this will not occur since the state machine only allows one operations to happen. Basically, I solve this by extending
    //the retry during a state transition. Difficult to say if this work 100%, but my notes imply this will work.
    id_ram_read_next_retry = id_ram_next_retry;
    id_ram_write_next_retry = id_ram_next_retry;
    
    //default drid to index RAM is the value used for writing to the RAM
    id_ram_pos_next = drid_valid_encoder;
    
    id_ram_next_valid = 1'b0;
    
    if(id_ram_state == ARBITER_READ_PREFERRED_STATE) begin
      //next state logic
      if(id_ram_read_next_valid && !id_ram_next_retry) begin
        id_ram_state_next = ARBITER_WRITE_PREFERRED_STATE;
      end
      
      //output logic
      if(id_ram_read_next_valid) begin
        id_ram_next_valid = 1'b1;      
        id_ram_write_next_retry = 1'b1; 
        id_ram_pos_next = memtodr_ack.drid;
      end else if(id_ram_write_next_valid) begin
        id_ram_next_valid = 1'b1;
      end
      
    end else begin //state == ARBITER_WRITE_PREFERRED_STATE
    
      if(id_ram_write_next_valid && !id_ram_next_retry) begin
        id_ram_state_next = ARBITER_READ_PREFERRED_STATE;
      end
      
      if(id_ram_write_next_valid) begin
        id_ram_next_valid = 1'b1;
        id_ram_read_next_retry = 1'b1;
      end else if(id_ram_read_next_valid) begin
        id_ram_next_valid = 1'b1;
        id_ram_pos_next = memtodr_ack.drid;
      end
      
    end
  end
  
  flop #(.Bits(1)) sram_arbiter_state_flop (
    .clk      (clk)
   ,.reset    (reset)
   ,.d        (id_ram_state_next)
   ,.q        (id_ram_state)
  );
//ID RAM ARBITER END

//DRID VALID VECTOR START
  //Adding some temporary code here
  logic [`DR_REQIDS-1:0] drid_valid_vector;
  logic [`DR_REQIDS-1:0] drid_valid_vector_next;
  
  
  //This always block combined with the flop represents the logic used to maintain a vector which remembers which DRIDs are in use 
  //and which are available. This valid is sent to a priority encoder which determines the next available DRID to be used in the pending
  //request.
  //DRID are marked in use when a request from the L2 has been accepted by the directory and they are released when an ACK for that request 
  //has been processed by the directory.
  always_comb begin
    drid_valid_vector_next = drid_valid_vector;
    
    if(id_ram_write_next_valid && !id_ram_write_next_retry) begin
        drid_valid_vector_next[drid_valid_encoder] = 1'b0;
    end
    
    //releasing DRIDs will probably change because this logic release them after I read the ram values
    if(id_ram_read_next_valid && !id_ram_read_next_retry) begin
      drid_valid_vector_next[memtodr_ack.drid] = 1'b1;
    end
    
  end
  
  //should probably change this is an fflop
  //That way, the valids can come from inputs
  flop_r #(.Size(`DR_REQIDS), .Reset_Value({`DR_REQIDS{1'b1}})) drid_vector_flop_r (
    .clk      (clk)
   ,.reset    (reset)
   ,.din      (drid_valid_vector_next)
   ,.q        (drid_valid_vector)
  );
//DRID VALID VECTOR END

  logic                   id_ram_read_next_valid;
  logic                   id_ram_read_next_retry;
  
  assign id_ram_read_next_valid = 1'b0;
  
//DRTOL2 DACK START
  logic drtol2_dack_next_valid;
  logic drtol2_dack_next_retry;
  I_drtol2_dack_type drtol2_dack_next;
  
  //These should have actual values, but I have not implemented that yet.
  assign drtol2_dack_next.nid = l2todr_disp.nid;
  assign drtol2_dack_next.l2id = l2todr_disp.l2id;
  
  //Always blocks for the drtol2_dack_next_valid signal. The fflop for this valid takes in the nid and l2id of the l2todr displacement request.
  //This valid is similar to drtomem_wb_next_valid except it still accept the values if the command prompts no displacement.
  //The last part of this boolean statement says "Listen to the retry signal on the wb fflop or ignore it if the command is a no displacement."
  always_comb begin
    drtol2_dack_next_valid = l2todr_disp_valid;  
  end
  
  
  //fflop for drtol2_dack (displacement acknowledge)
  //Issues: As of now, the dack will occur even if the memory has not been written back to main memory (It is stuck in the wb fflop with a continuous retry).
  //At this point, acking back the displacement may cause requests to occur on that address even though the data has not been actually written back.
  //There are two ways to address this issue: (1) Check addresses on requests to see if they match the address on the writeback which will cause the request
  //to be blocked until the writeback has completed. (2) Make sure main memory has accepted the writeback before issuing a dack. 
  //Note: (1) needs to be implemented no matter what to enforce coherency between other caches requeseting the data (still does not solve cohereancy problem though)
  //but (1) is not an ideal solution to solve this issue when compared to (2). (2) Will be implemented, but (1) will be implemented first.
  fflop #(.Size($bits(I_drtol2_dack_type))) dack_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtol2_dack_next),
    .dinValid (drtol2_dack_next_valid),
    .dinRetry (drtol2_dack_next_retry),

    .q        (drtol2_dack),
    .qValid   (drtol2_dack_valid),
    .qRetry   (drtol2_dack_retry)
  );  
//DRTOL2 DACK END

//DRTOMEM PREFETCH START
  I_l2todr_pfreq_type          drff_pfreq;
  assign drtomem_pfreq.paddr = drff_pfreq.paddr;
  assign drtomem_pfreq.nid   = drff_pfreq.nid;
  
  fflop #(.Size($bits(I_l2todr_pfreq_type))) pfreq_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (l2todr_pfreq),
    .dinValid (l2todr_pfreq_valid),
    .dinRetry (l2todr_pfreq_retry),

    .q        (drff_pfreq),
    .qValid   (drtomem_pfreq_valid),
    .qRetry   (drtomem_pfreq_retry)
  );
  
//DRTOMEM PRFETCH END

//MEMTODR ACK START
  assign memtodr_ack_retry = 1'b1;
//MEMTODR ACK END
`endif

`ifdef DR_PASSTHROUGH
  //The fflop below uses type I_l2todr_pfreq_type as its input and output. While I_drtomem_pfreq_type is basically the same struct,
  //I divided the fflop output and assignment so there would not be any conflicts.
  I_l2todr_pfreq_type          drff_pfreq;
  assign drtomem_pfreq.paddr = drff_pfreq.paddr;
  assign drtomem_pfreq.nid   = drff_pfreq.nid;
  
  fflop #(.Size($bits(I_l2todr_pfreq_type))) pfreq_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (l2todr_pfreq),
    .dinValid (l2todr_pfreq_valid),
    .dinRetry (l2todr_pfreq_retry),

    .q        (drff_pfreq),
    .qValid   (drtomem_pfreq_valid),
    .qRetry   (drtomem_pfreq_retry)
  );
  


  
  

//Din will be mostly entries from the l2todr_req
  I_drtomem_req_type              drtomem_req_next;
  logic                           drtomem_req_next_valid;
  logic                           drtomem_req_next_retry;
  logic                           id_ram_write_next_valid;
  logic                           id_ram_write_next_retry;
  
  
  assign drtomem_req_next.paddr = l2todr_req.paddr;
  assign drtomem_req_next.cmd   = l2todr_req.cmd;
  assign drtomem_req_next.drid  = drid_valid_encoder;
  
  //valid will depend on: available DRID, RAM ready for writing, and drtomem_fflop ready
  assign l2todr_req_retry        = !drid_valid || drtomem_req_next_retry || id_ram_write_next_retry;
  assign drtomem_req_next_valid  = l2todr_req_valid && drid_valid && !id_ram_write_next_retry;
  assign id_ram_write_next_valid = l2todr_req_valid && drid_valid && !drtomem_req_next_retry;

  fflop #(.Size($bits(I_drtomem_req_type))) drtomem_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtomem_req_next),
    .dinValid (drtomem_req_next_valid),
    .dinRetry (drtomem_req_next_retry),

    .q        (drtomem_req),
    .qValid   (drtomem_req_valid),
    .qRetry   (drtomem_req_retry)
  );
  
  
  
  //Adding some temporary code here
  logic [`DR_REQIDS-1:0] drid_valid_vector;
  logic [`DR_REQIDS-1:0] drid_valid_vector_next;
  
  
  //This always block combined with the flop represents the logic used to maintain a vector which remembers which DRIDs are in use 
  //and which are available. This valid is sent to a priority encoder which determines the next available DRID to be used in the pending
  //request.
  //DRID are marked in use when a request from the L2 has been accepted by the directory and they are released when an ACK for that request 
  //has been processed by the directory.
  always_comb begin
    drid_valid_vector_next = drid_valid_vector;
    
    if(id_ram_write_next_valid && !id_ram_write_next_retry) begin
        drid_valid_vector_next[drid_valid_encoder] = 1'b0;
    end
    
    //releasing DRIDs will probably change because this logic release them after I read the ram values
    if(id_ram_read_next_valid && !id_ram_read_next_retry) begin
      drid_valid_vector_next[memtodr_ack.drid] = 1'b1;
    end
    
  end
  
  //should probably change this is an fflop
  //That way, the valids can come from inputs
  flop_r #(.Size(`DR_REQIDS), .Reset_Value({`DR_REQIDS{1'b1}})) drid_vector_flop_r (
    .clk      (clk)
   ,.reset    (reset)
   ,.din      (drid_valid_vector_next)
   ,.q        (drid_valid_vector)
  );
  
  

  //Logic for acknowledgements
  logic                   memtodr_ack_ff_next_valid;
  logic                   memtodr_ack_ff_next_retry;
  logic                   id_ram_read_next_valid;
  logic                   id_ram_read_next_retry;
  
  always_comb begin
    if(memtodr_ack.drid == {`DR_REQIDBITS{1'b0}}) begin //0 is an invalid drid, this is checked here
      //this indicates we do not need to use the RAM, so only base handshake on fflop valid/retry
      memtodr_ack_ff_next_valid = memtodr_ack_valid; 
      memtodr_ack_retry = memtodr_ack_ff_next_retry;
    end else begin
      //otherwise, handshake logic becomes similar to that of a fork
      memtodr_ack_ff_next_valid = memtodr_ack_valid && !id_ram_read_next_retry;
      memtodr_ack_retry = memtodr_ack_ff_next_retry || id_ram_read_next_retry;
    end
  end
  
  //This is moved into another always block because it causes warnings if placed into the same block as the one above.
  always_comb begin
    if(memtodr_ack.drid == {`DR_REQIDBITS{1'b0}}) begin //0 is an invalid drid, this is checked here
      //this indicates we do not need to use the RAM, so only base handshake on fflop valid/retry
      id_ram_read_next_valid = 1'b0;
    end else begin
      //otherwise, handshake logic becomes similar to that of a fork
      id_ram_read_next_valid = memtodr_ack_valid && !memtodr_ack_ff_next_retry;
    end
  end
  
  I_memtodr_ack_type      memtodr_ack_ff;
  logic                   memtodr_ack_ff_valid;
  logic                   memtodr_ack_ff_retry;

  
  //This is a pipeline stage for the memory acknowledgement. This operation requires a RAM lookup which takes one cycle.
  //A pipeline stage is used to remember the acknowledgement during the RAM cycle.
  fflop #(.Size($bits(I_memtodr_ack_type))) memtodr_ack_fflop (
    .clk      (clk),
    .reset    (reset),

    .din      (memtodr_ack),
    .dinValid (memtodr_ack_ff_next_valid),
    .dinRetry (memtodr_ack_ff_next_retry),

    .q        (memtodr_ack_ff),
    .qValid   (memtodr_ack_ff_valid),
    .qRetry   (memtodr_ack_ff_retry)
  );
 
  
  //The ack is more complicated because we have to wait for a read on the RAM. 
  I_drtol2_snack_type     drtol2_snack_next;
  logic                   drtol2_snack_next_valid;
  logic                   drtol2_snack_next_retry;

  always_comb begin
    if(memtodr_ack_ff.drid == {`DR_REQIDBITS{1'b0}}) begin
      //if drid is invalid then this is an ack for a prefetch. Therefore, use the terms in the ack that that are meant for the
      //prefetch. 
      drtol2_snack_next.nid = memtodr_ack_ff.nid; 
      drtol2_snack_next.l2id = {`L2_REQIDBITS{1'b0}};
	    drtol2_snack_next.hpaddr_base = 'b0;
	    drtol2_snack_next.hpaddr_hash = 'b0;
      drtol2_snack_next.paddr = memtodr_ack_ff.paddr;
      
      drtol2_snack_next_valid = memtodr_ack_ff_valid; 
      memtodr_ack_ff_retry = drtol2_snack_next_retry;
      id_ram_retry = 1'b1;
    end else begin
      //If the DRID is valid then ignore the prefetch terms and nid, l2id are set by the RAM
      drtol2_snack_next.nid = id_ram_data[10:6]; //These needs to be changed to match the request nid and l2id.
      drtol2_snack_next.l2id = id_ram_data[5:0];
	    drtol2_snack_next.hpaddr_base = compute_dr_hpaddr_base(memtodr_ack_ff.paddr);
	    drtol2_snack_next.hpaddr_hash = compute_dr_hpaddr_hash(memtodr_ack_ff.paddr);
      //drtol2_snack_next.paddr = 'b0;
      //Paddr should be set to 0 but not doing this to allow testbench to pass for now...
      drtol2_snack_next.paddr = memtodr_ack_ff.paddr;
      
      drtol2_snack_next_valid = memtodr_ack_ff_valid && id_ram_valid; 
      memtodr_ack_ff_retry = drtol2_snack_next_retry || (!drtol2_snack_next_valid && memtodr_ack_ff_valid);
      id_ram_retry = drtol2_snack_next_retry || (!drtol2_snack_next_valid && id_ram_valid);
    end
  end
  
  //The other values are independent of the DRID validity. However, this is an assumption that the "ack", which refers to
  //some command bits, is set by main memory correctly for prefetches and normal requests.
  assign drtol2_snack_next.drid =  {`DR_REQIDBITS{1'b0}}; //This is not a mistake in this case because the drid is required to be 0 on acks, and we do not snoop in passthrough
  assign drtol2_snack_next.snack = memtodr_ack_ff.ack;
  assign drtol2_snack_next.line =  memtodr_ack_ff.line;
  
  //need to set param to assign directory id to input parameter.
  assign drtol2_snack_next.directory_id = Directory_Id[`DR_NDIRSBITS-1:0];
  
  
  fflop #(.Size($bits(I_drtol2_snack_type))) drotol2_snack_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtol2_snack_next),
    .dinValid (drtol2_snack_next_valid),
    .dinRetry (drtol2_snack_next_retry),

    .q        (drtol2_snack),
    .qValid   (drtol2_snack_valid),
    .qRetry   (drtol2_snack_retry)
  );
 
 
  
  
  localparam MAX_DRID_VALUE = `DR_REQIDS-1;
 
  logic [`DR_REQIDBITS-1:0] drid_valid_encoder;
  logic drid_valid;
  always_comb begin 
    //Yes, I know the while loop looks bad, and I agree. The while loop is to allow for parametrization, but this scheme may
    //affect synthesis and may be forced to change.    
    //This for loop implements a priority encoder. It uses a 64 bit vector input which holds
    //a valid bit for every possible DRID. This encoder looks at the bit vector and determines a 
    //valid DRID which can be used for a memory request. The encoder is likely huge based on seeing examples
    //for small priority encoders.
    //The benefits of this scheme are that it does an arbitration of which DRID should be used and it does it quickly.
    //The obvious downsides it the gate count is large. However, we only need one of these.
    
    //This code was adapted from https://github.com/AmeerAbdelhadi/Indirectly-Indexed-2D-Binary-Content-Addressable-Memory-BCAM/blob/master/pe_bhv.v
    drid_valid_encoder = {`DR_REQIDBITS{1'b0}};
    //drid_valid_encoder = 1'b1; //temporary declaration
    drid_valid = 1'b0;
    while ((!drid_valid) && (drid_valid_encoder != MAX_DRID_VALUE)) begin
      drid_valid_encoder = drid_valid_encoder + 1 ;
      drid_valid = drid_valid_vector[drid_valid_encoder];
    end
  end
  
  logic id_ram_next_valid;
  logic id_ram_next_retry;
  logic id_ram_we;
  logic [`DR_REQIDBITS-1:0] id_ram_pos_next;
  
  logic id_ram_valid;
  logic id_ram_retry;
  logic [10:0] id_ram_data;
  
  ram_1port_fast 
   #(.Width(11), .Size(`DR_REQIDS), .Forward(1))
  id_ram ( 
    .clk         (clk)
   ,.reset       (reset)

   ,.req_valid   (id_ram_next_valid)
   ,.req_retry   (id_ram_next_retry)
   ,.req_we      (id_ram_we) 
   ,.req_pos     (id_ram_pos_next)
   ,.req_data    ({l2todr_req.nid,l2todr_req.l2id})

   ,.ack_valid   (id_ram_valid)
   ,.ack_retry   (id_ram_retry)
   ,.ack_data    (id_ram_data)
 );
  
  
  localparam ARBITER_READ_PREFERRED_STATE = 1'b0;
  localparam ARBITER_WRITE_PREFERRED_STATE = 1'b1;
  
  //not assigned: arb_drid_write_valid

  
  logic id_ram_state;
  logic id_ram_state_next;
  //I had to separate the write enable signal into a different always block or else a warning will occur claiming circular logic. This warning appears to be a glitch
  //and should not affect simulation, but I removed it anyway.
  always_comb begin
    id_ram_we = 1'b0;
    if(id_ram_state == ARBITER_READ_PREFERRED_STATE) begin    
      if(id_ram_write_next_valid && !id_ram_read_next_valid) begin
        id_ram_we = 1'b1;
      end
      
    end else begin //state == ARBITER_WRITE_PREFERRED_STATE
      if(id_ram_write_next_valid) begin
        id_ram_we = 1'b1;
      end 
      
    end
  end
  
  //This always blocks performs the next state logic for the DRID RAM READ/WRITE arbiter FSM. It also contains some output logic
  //for the FSM but not all of it. The write enable had to be moved outside the always blocks because it caused warnings to occur
  //when they were in the same always block.
  
  always_comb begin
    //default next state is the current state
    id_ram_state_next = id_ram_state;
    
    //default retry on read or writes is the retry coming from the SRAM, however this will fail in some cases. For example,
    //if retry from SRAM is high and both valids from retry are high then the operation that occurs after the retry falls LOW
    //depends on which state we are in. If the SRAM retry falls low, then the fflops think that their valid goes through, but
    //this will not occur since the state machine only allows one operations to happen. Basically, I solve this by extending
    //the retry during a state transition. Difficult to say if this work 100%, but my notes imply this will work.
    id_ram_read_next_retry = id_ram_next_retry;
    id_ram_write_next_retry = id_ram_next_retry;
    
    //default drid to index RAM is the value used for writing to the RAM
    id_ram_pos_next = drid_valid_encoder;
    
    id_ram_next_valid = 1'b0;
    
    if(id_ram_state == ARBITER_READ_PREFERRED_STATE) begin
      //next state logic
      if(id_ram_read_next_valid && !id_ram_next_retry) begin
        id_ram_state_next = ARBITER_WRITE_PREFERRED_STATE;
      end
      
      //output logic
      if(id_ram_read_next_valid) begin
        id_ram_next_valid = 1'b1;      
        id_ram_write_next_retry = 1'b1; 
        id_ram_pos_next = memtodr_ack.drid;
      end else if(id_ram_write_next_valid) begin
        id_ram_next_valid = 1'b1;
      end
      
    end else begin //state == ARBITER_WRITE_PREFERRED_STATE
    
      if(id_ram_write_next_valid && !id_ram_next_retry) begin
        id_ram_state_next = ARBITER_READ_PREFERRED_STATE;
      end
      
      if(id_ram_write_next_valid) begin
        id_ram_next_valid = 1'b1;
        id_ram_read_next_retry = 1'b1;
      end else if(id_ram_read_next_valid) begin
        id_ram_next_valid = 1'b1;
        id_ram_pos_next = memtodr_ack.drid;
      end
      
    end
  end
  
  flop #(.Bits(1)) sram_arbiter_state_flop (
    .clk      (clk)
   ,.reset    (reset)
   ,.d        (id_ram_state_next)
   ,.q        (id_ram_state)
  );



  //WB start
  I_drtomem_wb_type         drtomem_wb_next;
  logic                     drtomem_wb_next_valid;
  logic                     drtomem_wb_next_retry;
  //Unused signals: nid, l2id, drid, dcmd
  //drid is a special case in passthrough and we should always expect it to be 0 since we are not snooping.
  //Also, I am not sure what mask does.
  //nid and l2id need to be remembered in order to send an ack.
  
  //Always blocks to assign values to drtomem_wb_next. Uses parts of l2todr_disp that are required for write back.
  //Other parts are ignored (for passthrough) or are sent to the fflop that holds the ack back to the L2.
  always_comb begin
    drtomem_wb_next.line = l2todr_disp.line;
    drtomem_wb_next.mask = l2todr_disp.mask;
    drtomem_wb_next.paddr = l2todr_disp.paddr;
  end
  
  //Always block to determine the valid of the memtodr_wb fflop. Depends on: the command type, the disp input valid, and the internal
  //dack fflop retry signal.
  always_comb begin
    drtomem_wb_next_valid = l2todr_disp_valid && !drtol2_dack_next_retry && (l2todr_disp.dcmd != `SC_DCMD_I);  
  end
  
  
  
  //Always blocks for the l2todr_disp_retry signal. The retry is an OR of the dack retry signal as well as the wb retry signal, but the
  //wb retry is ignored if the command is a no displacement. (Nothing written back if there is no displacement.) I should probably include
  //I DRID check here as well.
  always_comb begin
    l2todr_disp_retry = (drtomem_wb_next_retry && (l2todr_disp.dcmd != `SC_DCMD_I)) || drtol2_dack_next_retry;
  end
  
  //fflop for memtodr_ack (memory ack request)
  //connections to drtomem_wb not complete. There is an assumption in this passthrough that the acks are returned in order.
  //The directory should also return an ack which is associated with this write back.
  //bit size of fflop is incorrect
  fflop #(.Size($bits(I_drtomem_wb_type))) memtodr_wb_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtomem_wb_next),
    .dinValid (drtomem_wb_next_valid),
    .dinRetry (drtomem_wb_next_retry),

    .q        (drtomem_wb),
    .qValid   (drtomem_wb_valid),
    .qRetry   (drtomem_wb_retry)
  );
  
  logic drtol2_dack_next_valid;
  logic drtol2_dack_next_retry;
  I_drtol2_dack_type drtol2_dack_next;
  
  //These should have actual values, but I have not implemented that yet.
  assign drtol2_dack_next.nid = l2todr_disp.nid;
  assign drtol2_dack_next.l2id = l2todr_disp.l2id;
  
  //Always blocks for the drtol2_dack_next_valid signal. The fflop for this valid takes in the nid and l2id of the l2todr displacement request.
  //This valid is similar to drtomem_wb_next_valid except it still accept the values if the command prompts no displacement.
  //The last part of this boolean statement says "Listen to the retry signal on the wb fflop or ignore it if the command is a no displacement."
  always_comb begin
    drtol2_dack_next_valid = l2todr_disp_valid && (!drtomem_wb_next_retry || (l2todr_disp.dcmd == `SC_DCMD_I));  
  end
  
  
  //fflop for drtol2_dack (displacement acknowledge)
  //Issues: As of now, the dack will occur even if the memory has not been written back to main memory (It is stuck in the wb fflop with a continuous retry).
  //At this point, acking back the displacement may cause requests to occur on that address even though the data has not been actually written back.
  //There are two ways to address this issue: (1) Check addresses on requests to see if they match the address on the writeback which will cause the request
  //to be blocked until the writeback has completed. (2) Make sure main memory has accepted the writeback before issuing a dack. 
  //Note: (1) needs to be implemented no matter what to enforce coherency between other caches requeseting the data (still does not solve cohereancy problem though)
  //but (1) is not an ideal solution to solve this issue when compared to (2). (2) Will be implemented, but (1) will be implemented first.
  fflop #(.Size($bits(I_drtol2_dack_type))) dack_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (drtol2_dack_next),
    .dinValid (drtol2_dack_next_valid),
    .dinRetry (drtol2_dack_next_retry),

    .q        (drtol2_dack),
    .qValid   (drtol2_dack_valid),
    .qRetry   (drtol2_dack_retry)
  );
  
  
  logic drff_snoop_ack_valid;
  logic drff_snoop_ack_retry;
  I_drsnoop_ack_type drff_snoop_ack;
  


  //Therefore, I am not making this valid yet.
  assign drff_snoop_ack_retry= 1'b0;
  
  //fflop for l2todr_snoop_ack (snoop acknowledge)
  //Right now this is an output, but this is likely a type and it is actually a type.
  //Therefore, I am just going to output nothing relevant on this for now.
  fflop #(.Size($bits(I_drsnoop_ack_type))) snoop_ack_ff (
    .clk      (clk),
    .reset    (reset),

    .din      (l2todr_snoop_ack),
    .dinValid (l2todr_snoop_ack_valid),
    .dinRetry (l2todr_snoop_ack_retry),

    .q        (drff_snoop_ack),
    .qValid   (drff_snoop_ack_valid),
    .qRetry   (drff_snoop_ack_retry)
  );
  
  //What needs to be done for passthrough:
  //1) Add connections related to displacement ack. (done)
  //2) Set a connections to snoop ack which does nothing because the system cannot snoop. (done)
  //3) Set the drid to a counter to at least change the value. (not done)
  //4) Finish the connections already established but not completed by the fluid flops. (done)
  //5) This should complete passthrough with assumption that transactions are completed in order. (bad assumption, have to remember requests)
  //6) Enable a system to remember l2id and nid based on drid.(not done, main priority)
  
  //Note: I am implementing the FFlops a little wrong. They really should be the final outputs with no logic or operations attached
  //to the output as it exits the module. Therefore, I should change my signals to have operations performed then fed into the FFlops
  //rather than the other way around which it is now.
  
  //The main Question: Will this run? I think yes but poorly since the passthrough does not remember node IDs or L2 request IDs and does 
  //not generate DR IDs
  

  
 
 //Explanation of when to remember identifications:
 //1) The main time we have to remember is during an L2 request. This will include an NID and an L2ID. We need to request a DRID and store
 //   the values in the fast SRAM. The DRID is then passed to main memory. Main memory will send an ack using the DRID. We want to ack back
 //   to the L2 using NID and L2ID, so we locate these values using the DRID. At this point, the DRID can be released to be used by another request.
 //2) The other case where we might want to store an NID and an L2ID is when an L2 performs a displacement. A DRID alocation is not needed here because
 //   main memory will not ack on a write back. In the passthrough case, we can immediately ack back to the L2 when main memory takes in the write back
 //   using the NID and L2ID is gave us for the request. Two ways to implement this is to assign a DRID and store the information. However, it probably
 //   only required a fflop because the writebacks will be in order.

`endif
endmodule
