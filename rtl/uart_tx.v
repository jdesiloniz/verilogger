module uart_tx #(parameter BAUD_COUNT = 104, BAUD_COUNT_SIZE = 7) (
	input 	wire				clk,
	input 	wire 		[7:0]	data,
	input 	wire 				stb,
	output 	wire 				tx,
	output 	reg 				busy
);

	// Baud counter
	reg baud_stb;
	reg [6:0] baudc;

	initial begin
		baudc = BAUD_COUNT - 1'b1;
		baud_stb = 0;
	end

	always @(posedge clk)
		if (busy) begin
			if (baudc == 0)
				baudc <= BAUD_COUNT - 1'b1;
			else
				baudc <= baudc - 1'b1;
		end

	always @(posedge clk)
		if (busy && baudc == 7'b1)
			baud_stb <= 1'b1;
		else baud_stb <= 0;

	// Bit counter
	reg [3:0] bitc;
	initial bitc = 0;

	always @(posedge clk)
		if (baud_stb) begin
			if (bitc == 4'd09)
				bitc <= 0;
			else bitc <= bitc + 1'b1;
		end

	// Shift register
	reg [9:0] tx_shift;
	initial tx_shift = 10'b11_1111_1111;

	always @(posedge clk)
		if (stb && !busy)
			tx_shift <= { 1'b1, data, 1'b0 };
		else if (busy && baud_stb)
			tx_shift <= { 1'b1, tx_shift[9:1] };
		else if (!busy)
			tx_shift <= 10'b11_1111_1111;

	// Busy signal
	initial busy = 0;
	always @(posedge clk)
		if (stb && !busy)
			busy <= 1'b1;
		else if (baud_stb && bitc == 4'd09)
			busy <= 0;

	// TX signal
	assign tx = tx_shift[0];

	// Formal verification

`ifdef FORMAL
`ifdef TXUART
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif

	reg f_past_valid;
	initial f_past_valid = 0;
	always @(posedge clk)
		f_past_valid <= 1'b1;

	reg [7:0] f_data;
	initial f_data = 0;
	always @(posedge clk) begin
		if (stb)
			f_data <= data;

		if (busy && f_past_valid)
			assume($past(f_data) == f_data);
	end

	// Data shouldn't change while busy:
	always @(posedge clk)
		if (busy)
			assume(data == $past(data));

	always @(posedge clk)
		assert(baud_stb == (baudc == 0));

	// Baud counter should count
	always @(posedge clk) begin
		if (f_past_valid && $past(busy) && $past(baudc) != 0)
			assert(baudc == $past(baudc - 1'b1));

		if (f_past_valid && busy && $past(baudc) == 0)
			assert(baudc == BAUD_COUNT - 1'b1);
	end

	// Shift register should shift correctly when it should
	always @(posedge clk)
		if ($past(baud_stb) && f_past_valid)
			assert(tx_shift[8:0] == $past(tx_shift[9:1]));

	// Shift register should be loaded correctly
	always @(posedge clk) begin
		if (f_past_valid && $past(stb && !busy))
			assert(tx_shift == { 1'b1, data, 1'b0 });
	end

	// TX signal
	always @(posedge clk) begin
		if (!busy && $past(!busy))
			assert(tx == 1'b1);
		else assert(tx == tx_shift[0]);
	end
`endif

endmodule // uart_tx