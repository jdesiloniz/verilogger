module logger_example_lattice(
	input 	wire						clk,
	output 	wire 						logger_full,
	output 	wire 						tx
);
	// RAM:
	localparam AW = 11;
	localparam DW = 16;
	localparam FIFO_SIZE = 2 ** AW;

	wire 	[AW-1:0] 			mem_addr_r;
	wire 	[AW-1:0] 			mem_addr_w;
	wire 		  				mem_rw;
	wire 	[DW-1:0] 			mem_data_in;
	wire 	[DW-1:0] 			mem_data_out;

	wire 	[AW-1:0]			mem_addr;
	assign mem_addr = (mem_rw) ? mem_addr_r : mem_addr_w;

	lattice_single_port_genram #(.AW(AW), .DW(DW)) genram(
		.clk     (clk),
		.addr    (mem_addr),
		.rw      (mem_rw),
		.data_in (mem_data_in),
		.data_out(mem_data_out)
	);

	// UART:
	localparam 			BAUD_COUNT = 104;		// Baud divider (12000000/104 for 115200)
	localparam			BAUD_COUNT_SIZE = 7;	// Size of baud divider
	wire 				uart_busy;
	wire 				uart_stb;
	wire 	[7:0] 		uart_data;

	uart_tx #(.BAUD_COUNT(BAUD_COUNT), .BAUD_COUNT_SIZE(BAUD_COUNT_SIZE)) UART(
		.clk (clk),
		.data(uart_data),
		.stb (uart_stb),
		.tx  (tx),
		.busy(uart_busy)
	);

	// Logger:
	localparam LOG_COUNT = 8;
	localparam LOG_SIZE = LOG_COUNT * 8;
	localparam LOG_SIZE_WIDTH = $clog2(LOG_SIZE);

	reg 	[LOG_SIZE-1:0]		logger_text;
	wire 						logger_stb;
	wire 						logger_busy;
	logger #(
		.AW(AW),						// Address width in memory
		.DW(DW),						// Data width in memory
		.COUNT(LOG_COUNT),				// Number of characters per line
		.COUNT_SIZE(LOG_SIZE_WIDTH),	// Size of number of characters per line
		.FIFO_SIZE(FIFO_SIZE))			// Size of FIFO in bytes (2^AW)
	LOG0(.clk        (clk),
		.text        (logger_text),
		.stb         (logger_stb),
		.busy        (logger_busy),
		.full        (logger_full),
		.ext_stb	 (uart_stb),
		.ext_data	 (uart_data),
		.ext_busy	 (uart_busy),
		.mem_addr_w  (mem_addr_w),
		.mem_addr_r  (mem_addr_r),
		.mem_rw      (mem_rw),
		.mem_data_in (mem_data_in),
		.mem_data_out(mem_data_out)
	);

	// Second counter
	reg 	[23:0]	time_divider_cnt;

	initial time_divider_cnt = 14'd10_000;

	always @(posedge clk)
		if (time_divider_cnt == 0)
			time_divider_cnt <= 14'd10_000;
		else time_divider_cnt <= time_divider_cnt - 1'b1;

	// Logging logic
	initial logger_text <= { "HELLO!!", 8'h0D };

	assign logger_stb = (time_divider_cnt == 0 && !logger_busy && !logger_full);

endmodule // logger_example_lattice