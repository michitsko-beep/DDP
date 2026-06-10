
import xbox_def_pkg::*;

//-----------------------------------------------------------------------

module cgol_xlr (

  // DO NOT TOUCH INTERFACE

  input        clk,
  input        rst_n,  
 
  // Command Status Register Interface
  input        [XBOX_NUM_REGS-1:0][31:0] host_regs,               // regs accelerator write data, reflecting logicisters content as most recently written by SW over APB
  input  logic [XBOX_NUM_REGS-1:0]       host_regs_valid_pulse,   // logic written by host (APB) (one per register)   
  output logic [XBOX_NUM_REGS-1:0][31:0] host_regs_data_out,      // regs accelerator write data,  this is what SW will read when accessing the register  
                                                                  // provided that the register specific host_regs_valid_out is asserted
  output logic [XBOX_NUM_REGS-1:0]       host_regs_valid_out,     // logic accelerator (one per register)   
  input  logic [XBOX_NUM_REGS-1:0]       host_regs_read_pulse,    // Indicate register actual read by host to allow clear on read if desired.

  mem_intf_read.client_read   mem_intf_read,
  mem_intf_write.client_write mem_intf_write 
 );
 
 //-----------------------------------------------------------------------

  // Max possible dimenssions avtual confifured dimenssions might be less.

  localparam MAX_HEIGHT = 256;  // MAX Height of cgol grid (max number of rows)
  localparam MAX_WIDTH  = 256;  // Max number cells in a cgol grid row , must be an integer multiple of 8
  localparam MAX_WIDTH_BYTES = MAX_WIDTH/8 ;
  
 
  //======================================================================================================== 
 
 // TEMPORARILY DRIVING ALL MODULE OUTPUTS TO 0  
 // TO AVOID UNKNOWN VALUES 'X' PROPAGATION INTO THE SYSTEM  
 // REMOVE THIS SECTION PRIOR TO ACCELERATOR IMPLEMENTATION


  always_comb begin  
    host_regs_valid_out = 0; // Default
    host_regs_valid_out           = 0;
    mem_intf_write.mem_size_bytes = 0;   
    mem_intf_read.mem_size_bytes  = 0;
    mem_intf_write.mem_data       = 0;
    mem_intf_write.mem_start_addr = 0;   
    mem_intf_read.mem_start_addr  = 0;  
    mem_intf_read.mem_req         = 0;
    mem_intf_write.mem_req        = 0;   
  end 
   
 //======================================================================================================== 
 
 /***********************************/
 /* MODULE IMPLEMENTATION CODE HERE */
 /***********************************/

endmodule