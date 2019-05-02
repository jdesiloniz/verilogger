module logger #(parameter COUNT = 16, COUNT_SIZE = 5, AW = 10, DW = 8, FIFO_SIZE = 1024)(
	input 	wire						clk,
	input 	wire 	[MAX_SIZE-1:0] 		text,
	input 	wire 						stb,
	output 	wire 						busy,
	output 	wire 						full,

	// External device (UART, SPI...)
	output 	wire 						ext_stb,
	output 	wire 	[7:0]				ext_data,
	input 	wire 						ext_busy,

	// Memory control
	output 	wire 	[AW-1:0] 			mem_addr_w,
	output 	wire 	[AW-1:0] 			mem_addr_r,
	output 	wire 		  				mem_rw,
	output  wire 	[DW-1:0] 			mem_data_in,
	input 	wire 	[DW-1:0] 			mem_data_out
);

	// FIFO:
	wire 				fifo_stb;
	wire 				fifo_op;
	wire 				fifo_full;
	wire 				fifo_empty;
	wire 				fifo_busy;
	wire 	[DW-1:0]	fifo_data_in;
	wire 	[DW-1:0]	fifo_data_out;

	fifo #(.SIZE(FIFO_SIZE), .DW(DW), .AW(AW)) F0(
		.clk           (clk),
		.data_write    (fifo_data_in),
		.op            (fifo_op),
		.stb           (fifo_stb),
		.data_read     (fifo_data_out),
		.full          (fifo_full),
		.empty         (fifo_empty),
		.mem_addr_w    (mem_addr_w),
		.mem_addr_r    (mem_addr_r),
		.mem_write_en  (mem_rw),
		.mem_data_read (mem_data_out),
		.mem_data_write(mem_data_in)
	);

	assign full = fifo_full;

	localparam MAX_SIZE = COUNT << 3;
	localparam CHARACTER_SHIFT = DW >> 3;

	// Byte counter
	reg 						bytec_stb;
	reg 	[COUNT_SIZE-1:0]	bytec;				
	wire bytec_zero = (bytec < CHARACTER_SHIFT);

	initial bytec = COUNT - 1'b1;
	always @(posedge clk)
		if (bytec_stb == 1'b1)
			if (!bytec_zero)
				bytec <= bytec - CHARACTER_SHIFT;
			else bytec <= COUNT - 1'b1;

	// Text register/shifting
	wire 									text_reg_load_stb;
	reg [MAX_SIZE-1:0] 						text_reg;
	assign text_reg_load_stb = (fifo_state == ST_FIFO_IDLE && stb && !busy);

	always @(posedge clk)
		if (text_reg_load_stb)
			text_reg <= text;
		else if (bytec_stb)
			text_reg <= {text_reg[MAX_SIZE-DW:0], {DW{1'b0}} };

	assign fifo_data_in = text_reg[MAX_SIZE-1:MAX_SIZE-DW];

	// FIFO drain counter
	reg 						fifo_drain_ena;
	reg 	[COUNT_SIZE-1:0]	fifo_drainc;

	always @(posedge clk) begin
		if (!fifo_drain_ena)
			fifo_drainc <= COUNT - 1'b1;
		else if (extc_stb) begin
			if (fifo_drainc > 0)
				fifo_drainc <= fifo_drainc - 1'b1;
			else fifo_drainc <= COUNT - 1'b1;
		end
	end

	// FIFO FSM
	localparam ST_FIFO_IDLE = 0;
	localparam ST_FIFO_STORE = 2'd1;
	localparam ST_FIFO_DRAIN = 2'd2;
	localparam ST_FIFO_CHECK_FULL = 2'd3;

	reg [1:0] fifo_state;
	initial fifo_state = ST_FIFO_IDLE;

	always @(posedge clk) begin
		bytec_stb <= 0;
		fifo_drain_ena <= 0;

		case (fifo_state)
			ST_FIFO_IDLE:
				if (stb && !busy && !full) begin
					fifo_state <= ST_FIFO_STORE;
				end
			ST_FIFO_STORE: begin
				bytec_stb <= 1'b1;

				if (bytec_zero)
					fifo_state <= ST_FIFO_IDLE;
				else if (full) begin
					bytec_stb <= 0;
					fifo_drain_ena <= 1'b1;
					fifo_state <= ST_FIFO_DRAIN;
				end else fifo_state <= ST_FIFO_CHECK_FULL;
			end

			ST_FIFO_DRAIN: begin
				fifo_drain_ena <= 1'b1;
				if (fifo_drainc == 0)
					fifo_state <= ST_FIFO_STORE;
			end

			ST_FIFO_CHECK_FULL: begin
				if (full)
					fifo_state <= ST_FIFO_DRAIN;
				else fifo_state <= ST_FIFO_STORE;
			end

		endcase // fifo_state
	end

	// EXT char counter
	localparam EXT_COUNTER_SIZE = 4;			// TODO: Find a way to generalize this
	reg 										extc_stb;
	reg 	[EXT_COUNTER_SIZE-1:0]				extc;
	reg 	[DW-1:0]							ext_data_reg;

	initial extc = CHARACTER_SHIFT - 1'b1;
	initial extc_stb = 0;
	initial ext_data_reg = 0;

	always @(posedge clk)
		if (ext_state == ST_EXT_WAIT)
			extc <= CHARACTER_SHIFT - 1'b1;
		else if (extc_stb == 1'b1)
			if (extc > 0)
				extc <= extc - 1'b1;
			else extc <= CHARACTER_SHIFT - 1'b1;

	always @(posedge clk) begin
		if (extc_stb == 1'b1)
			ext_data_reg <= { ext_data_reg[DW-8:0], 8'b0 };
		else if (ext_state == ST_EXT_PULL)
			ext_data_reg <= fifo_data_out;
	end

	assign ext_data = ext_data_reg[DW-1:DW-8];

	// External device FSM
	localparam ST_EXT_WAIT = 0;
	localparam ST_EXT_PULL = 2'd1;
	localparam ST_EXT_READ = 2'd2;
	localparam ST_EXT_SEND = 2'd3;
	
	reg [1:0] ext_state;
	initial ext_state = ST_EXT_WAIT;

	always @(posedge clk) begin
		extc_stb <= 0;

		case (ext_state)
			ST_EXT_WAIT:
				if (!fifo_empty)
					ext_state <= ST_EXT_PULL;

			ST_EXT_PULL:
				if (!fifo_busy)
					ext_state <= ST_EXT_READ;

			ST_EXT_READ:
				ext_state <= ST_EXT_SEND;

			ST_EXT_SEND:
				if (!ext_busy) begin
					if (extc > 0)
						extc_stb <= 1'b1;
					else ext_state <= ST_EXT_WAIT;
				end
		endcase
	end

	// Control signals
	assign fifo_stb = ((fifo_state == ST_FIFO_STORE && !full)||ext_state == ST_EXT_PULL);
	assign fifo_op = (fifo_state != ST_FIFO_STORE);
	assign fifo_busy = (fifo_state == ST_FIFO_STORE);
	assign ext_stb = (ext_state == ST_EXT_SEND);

	assign busy = fifo_busy;

	// Formal verification

`ifdef FORMAL
`ifdef LOGGER

	reg f_past_valid;
	initial f_past_valid = 0;

	always @(posedge clk)
		f_past_valid <= 1'b1;

	// Byte counter
	always @(posedge clk)
		assert(bytec < COUNT);

	always @(posedge clk)
		if (f_past_valid && $past(!bytec_stb))
			assert($past(bytec) == bytec);

	// Avoid clashes between FIFO writes and FIFO reads
	always @(posedge clk)
		if (fifo_state == ST_FIFO_STORE)
			assert(!fifo_op);

	always @(posedge clk)
		if (ext_state == ST_EXT_PULL && !fifo_busy)
			assert(fifo_op && fifo_state != ST_FIFO_STORE);

	// Storing bytes in the FIFO
	always @(posedge clk)
		if (f_past_valid && $past(fifo_state == ST_FIFO_STORE) && $past(!full))
			assert(bytec_stb);

	// Text shift register
	always @(posedge clk)
		if (f_past_valid && $past(bytec_stb) && $past(!text_reg_load_stb))
			assert(text_reg[15:8] == $past(text_reg[7:0]));

	// We should be sending the right data to the UART
	always @(posedge clk)
		if (f_past_valid && uart_state == ST_EXT_SEND)
			assert(ext_data == $past(fifo_data_out));

	// We shouldn't send anything if the FIFO is empty
	always @(posedge clk)
		if (f_past_valid && $past(ext_state == ST_EXT_WAIT) && $past(fifo_empty))
			assert(ext_state == ST_EXT_WAIT);

	always @(posedge clk)
		cover(ext_stb);

	always @(posedge clk)
		cover(fifo_stb);

`endif
`endif

endmodule // logger