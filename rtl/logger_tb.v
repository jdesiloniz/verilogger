module logger_tb();

reg clk = 0;
wire tx;

  // RAM:
  localparam AW = 11;
  localparam DW = 16;

  wire  [AW-1:0]      mem_addr_r;
  wire  [AW-1:0]      mem_addr_w;
  wire                mem_rw;
  wire  [DW-1:0]      mem_data_in;
  wire  [DW-1:0]      mem_data_out;

  wire  [AW-1:0]      mem_addr;
  assign mem_addr = (mem_rw) ? mem_addr_r : mem_addr_w;

  lattice_single_port_genram #(.AW(AW), .DW(DW)) genram(
    .clk     (clk),
    .addr    (mem_addr),
    .rw      (mem_rw),
    .data_in (mem_data_in),
    .data_out(mem_data_out)
  );

  // UART:
  localparam      BAUD_COUNT = 2;
  localparam      BAUD_COUNT_SIZE = 7;

  wire [7:0]  uart_data;
  wire        uart_stb;
  wire        uart_busy;
  wire        uart_tx;

  uart_tx #(.BAUD_COUNT(BAUD_COUNT), .BAUD_COUNT_SIZE(BAUD_COUNT_SIZE)) UART(
    .clk (clk),
    .data(uart_data),
    .stb (uart_stb),
    .tx  (uart_tx),
    .busy(uart_busy)
  );

  // Logger:
  reg   [127:0]   logger_text;
  reg             logger_stb;
  wire            logger_busy;
  logger #(
    .AW(AW),        // Address width in memory
    .DW(DW),        // Data width in memory
    .COUNT(8),       // Number of characters per line
    .COUNT_SIZE(5),     // Size of number of characters per line
    .FIFO_SIZE(4096))   // Size of FIFO in bytes (2^AW)
  LOG0(.clk      (clk),
    .text        (logger_text),
    .stb         (logger_stb),
    .busy        (logger_busy),
    .full        (logger_full),
    .ext_stb     (uart_stb),
    .ext_data    (uart_data),
    .ext_busy    (uart_busy),
    .mem_addr_w  (mem_addr_w),
    .mem_addr_r  (mem_addr_r),
    .mem_rw      (mem_rw),
    .mem_data_in (mem_data_in),
    .mem_data_out(mem_data_out)
  );

always 
  # 1 clk <= ~clk;

initial begin
  $dumpfile("logger_tb.vcd");
  $dumpvars(0, logger_tb);

  #10 logger_text <= "HELLO!!!";
  #10 logger_stb <= 1'b1;

  #500000 $display("Simulation ended.");
  $finish;
end

endmodule