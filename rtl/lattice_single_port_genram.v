module lattice_single_port_genram #(parameter AW = 5, parameter DW = 8)(
	input 	wire 				clk,
	input 	wire 	[AW-1:0] 	addr,
	input 	wire 				rw,
	input 	wire 	[DW-1:0] 	data_in,
	output 	reg 	[DW-1:0] 	data_out
);

localparam SIZE = 2 ** AW;
reg [DW-1:0] data [0: SIZE - 1];

always @(posedge clk)
	if (rw == 1)
		data_out <= data[addr];
	else data[addr] <= data_in;

endmodule // lattice_single_port_genram