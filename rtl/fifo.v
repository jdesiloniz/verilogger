module fifo #(parameter SIZE = 10, DW = 8, AW = 4) (
	input 	wire	 			clk,
	input	wire	[DW-1:0]	data_write,
	input	wire				op,			// 0 - push/write, 1 - pull/read
	input	wire 				stb,
	output	wire 	[DW-1:0]	data_read,
	output 	wire 				full,
	output 	wire 				empty,

	// Memory access
	output wire 	[AW-1:0]	mem_addr_w,
	output wire 	[AW-1:0]	mem_addr_r,
	output wire 				mem_write_en,
	input  wire 	[DW-1:0]	mem_data_read,
	output wire 	[DW-1:0]	mem_data_write
);

	// Address pointers
	reg 	[AW-1:0]	ptr_writes;
	reg 	[AW-1:0]	ptr_reads;
	wire 	[AW-1:0]	ptr_writes_after, ptr_reads_after;

	initial begin
		ptr_writes = 0;
		ptr_reads = 0;
	end

	wire [AW-1:0] max_addr = SIZE - 1'b1;

	assign ptr_reads_after 	= (ptr_reads >= max_addr) ? 0 : ptr_reads + 1'b1;
	assign ptr_writes_after = (ptr_writes >= max_addr) ? 0 : ptr_writes + 1'b1;

	// Full / empty signals
	assign full = (ptr_writes_after == ptr_reads);
	assign empty = (ptr_writes == ptr_reads);

	// Memory addresses
	assign mem_write_en = (op == 0 && ~full && stb) ? 0 : 1'b1;
	assign mem_data_write = data_write;
	assign mem_addr_w	= ptr_writes;
	assign mem_addr_r	= ptr_reads;
	assign data_read = mem_data_read;

	// Push
	always @(posedge clk)
		if (stb && ~full && op == 0)
			ptr_writes <= ptr_writes_after;

	// Pull
	always @(posedge clk)
		if (stb && ~empty && op == 1'b1)
			ptr_reads <= ptr_reads_after;

// Formal verification

`ifdef FORMAL
`ifdef FIFO

	reg f_past_valid;
	initial f_past_valid = 0;

	always @(posedge clk)
		f_past_valid <= 1'b1;

	// FIFO can't write nor read beyond the memory limits
	always @(posedge clk)
		assert(ptr_writes < SIZE && ptr_reads < SIZE);

	// FIFO's full signal should always be active if we're really full
	always @(posedge clk)
		if (ptr_writes_after == ptr_reads)
			assert(full);

	// Same for empty signal
	always @(posedge clk)
		if (ptr_writes == ptr_reads)
			assert(empty);

	// Writing to a full FIFO doesn't have any effect
	always @(posedge clk)
		if (f_past_valid && $past(op == 0) && $past(stb) && $past(full))
			assert(full && $past(ptr_writes) == ptr_writes);

	// Reading from an empty FIFO doesn't have any effect
	always @(posedge clk)
		if (f_past_valid && $past(op == 1'b1) && $past(stb) && $past(empty))
			assert(empty && $past(ptr_reads) == ptr_reads);

	// While writing we don't touch the reading pointer
	always @(posedge clk)
		if (f_past_valid && $past(op == 0) && $past(stb))
			assert($past(ptr_reads) == ptr_reads);

	// And vice-versa...
	always @(posedge clk)
		if (f_past_valid && $past(op == 1'b1) && $past(stb))
			assert($past(ptr_writes) == ptr_writes);

	// Obviously we can write to a non-full FIFO
	always @(posedge clk)
		if (f_past_valid && $past(op == 0) && $past(stb) && $past(!full))
			assert(ptr_writes == $past(ptr_writes_after));

	// And we can read from a non-empty FIFO
	always @(posedge clk)
		if (f_past_valid && $past(op == 1'b1) && $past(stb) && $past(!empty))
			assert(ptr_reads == $past(ptr_reads_after));

	// Check we're reading the right data from memory
	always @(posedge clk)
		if (op == 1'b1)
			assert(data_read == mem_data_read);

	// And we're writing the right data to memory
	always @(posedge clk)
		if (op == 0 && ~full)
			assert(data_write == mem_data_write);

	// Also that we can't write to memory if FIFO is full
	always @(posedge clk)
		if (f_past_valid && $past(stb) && $past(op == 0) && $past(full))
			assert(mem_write_en == 1'b1);

	// We shouldn't get into a full situation after a pull
	always @(posedge clk)
		if (f_past_valid && $past(stb) && $past(op == 1'b1))
			assert(~full);

	// And obviously it should be impossible to be empty after a push
	always @(posedge clk)
		if (f_past_valid && $past(stb) && $past(op == 0))
			assert(~empty);
`endif
`endif

endmodule // fifo