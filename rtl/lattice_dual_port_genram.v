module lattice_dual_port_genram #(parameter AW = 8, DW = 8)(
		input wire 	[DW-1:0] 	data_in,
		input wire 				wclk,
		input wire 				rclk,
		input wire 	[AW-1:0] 	addr_w,
		input wire 	[AW-1:0] 	addr_r,
		output reg 	[DW-1:0] 	data_out,
		input 					wr_en
	);

	reg [DW-1:0] mem [(1<<AW)-1:0];

  	always @(posedge wclk) // Write memory.
  	if (wr_en)
  	    mem[addr_w] <= data_in; // Using write address bus.

  	always @(posedge rclk) // Read memory.
	  	data_out <= mem[addr_r]; // Using read address bus.

endmodule // lattice_dual_port_genram