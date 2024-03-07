module save_handler (
  input logic          clk_74a,
  input logic          clk_sys,
  input logic          reset,
  input logic          external_reset_s,
  input logic          pll_core_locked,

  input logic          bridge_rd,
  input logic          bridge_wr,
  input logic          bridge_endian_little,
  input logic  [31:0]  bridge_addr,
  input logic  [31:0]  bridge_wr_data,
  output logic [31:0]  bridge_rd_data,

  output logic [9:0]   datatable_addr,
  output logic         datatable_wren,
  output logic [31:0]  datatable_data,
  input  logic [31:0]  datatable_q,

  output logic         bk_wr,
  output logic         bk_rtc_wr,
  output logic [16:0]  bk_addr,
  output logic [15:0]  bk_data,
  input logic  [15:0]  bk_q,

  input logic          cart_has_save,
  input logic  [7:0]   ram_mask_file,
  input logic          cart_download,
  input logic  [31:0]  RTC_timestampOut,
  input logic  [47:0]  RTC_savedtimeOut,
  input logic          RTC_inuse,
  input logic          RTC_valid,
  output logic [31:0]  loaded_save_size,
  output logic         loading_done
);

  assign loaded_save_size = 0;

  data_unloader #(
    .ADDRESS_MASK_UPPER_4 (4'h2),
    .ADDRESS_SIZE         (18),
    .READ_MEM_CLOCK_DELAY (15),
    .INPUT_WORD_SIZE      (2)
  ) save_data_unloader (
    .clk_74a              (clk_74a),
    .clk_memory           (clk_sys),

    .bridge_rd            (bridge_rd),
    .bridge_endian_little (bridge_endian_little),
    .bridge_addr          (bridge_addr),
    .bridge_rd_data       (bridge_rd_data),

    .read_en              (),
    .read_addr            (unloader_addr),
    .read_data            (unloader_din)
  );

  data_loader #(
    .ADDRESS_MASK_UPPER_4       (4'h2),
    .ADDRESS_SIZE               (18),
    .WRITE_MEM_CLOCK_DELAY      (15),
    .WRITE_MEM_EN_CYCLE_LENGTH  (3),
    .OUTPUT_WORD_SIZE           (2)
  ) save_data_loader (
    .clk_74a              (clk_74a),
    .clk_memory           (clk_sys),

    .bridge_wr            (bridge_wr),
    .bridge_endian_little (bridge_endian_little),
    .bridge_addr          (bridge_addr),
    .bridge_wr_data       (bridge_wr_data),

    .write_en             (write_en),
    .write_addr           (loader_addr),
    .write_data           (bk_data_int)
  );

  assign bk_rtc_wr = rtc_wr_out;

  logic [17:0] save_size_bytes;
  logic [17:0] loader_addr;
  logic [17:0] unloader_addr;
  logic [15:0] unloader_din;
  logic [15:0] loader_dout;
  logic write_en;
  logic rtc_wr_in, rtc_wr_out;
  logic [15:0] bk_data_int;
  logic [16:0] RTCaddr;
  logic [15:0] rtc_dout;


  always_ff @(posedge clk_74a) begin
    if (reset) begin
      datatable_addr <= 0;
      datatable_data <= 0;
      datatable_wren <= 0;
    end else begin
      // Data slot index 1, not id 1
      datatable_addr <= 1 * 2 + 1;
      // Write sram size
      datatable_wren <= 1;

      if(RTC_inuse) begin
        datatable_data <= save_size_bytes + 16;
      end else begin
        datatable_data <= save_size_bytes;
      end
    end
  end

  always_comb begin
    if (cart_has_save) begin
      case(ram_mask_file)
        8'h01   : save_size_bytes = 512;
        8'h03   : save_size_bytes = 2048;
        8'h0F   : save_size_bytes = 8192;
        8'h3F   : save_size_bytes = 32768;
        8'h7F   : save_size_bytes = 65536;
        8'hFF   : save_size_bytes = 131072;
        default : save_size_bytes = 0;
      endcase
    end else begin
      save_size_bytes = 0;
    end
  end

  always_comb begin
    if (write_en) begin
      bk_addr = loader_addr[17:1];
    end else if (rtc_wr_out) begin
      bk_addr = RTCaddr;
    end else begin
      bk_addr = unloader_addr[17:1];
    end
  end

  always_comb begin
    if (unloader_addr >= save_size_bytes) begin
      case(unloader_addr[8:1])
        8'h00   : unloader_din = RTC_timestampOut[15:0];
        8'h01   : unloader_din = RTC_timestampOut[31:16];
        8'h02   : unloader_din = RTC_savedtimeOut[15:0];
        8'h03   : unloader_din = RTC_savedtimeOut[31:16];
        8'h04   : unloader_din = RTC_savedtimeOut[47:32];
        default : unloader_din = 16'hFFFF;
      endcase
    end else begin
      unloader_din = bk_q;
    end
  end

  always_comb begin
    if (loader_addr >= save_size_bytes) begin
      bk_wr     = 0;
      rtc_wr_in = write_en;
    end else begin
      bk_wr     = write_en;
      rtc_wr_in = 0;
    end
  end

  always_comb begin
    if(rtc_wr_out) begin
      bk_data = rtc_dout;
    end else begin
      bk_data = bk_data_int;
    end
  end

RTC_loader RTC_loader(
  .clk_sys(clk_sys),
  .reset(reset),
  .external_reset_s(external_reset_s),

  .cart_download(cart_download),
  .loading_done(loading_done),
  .RTC_valid(RTC_valid),

  .addr_in(loader_addr[17:1]),
  .data_in(bk_data_int),
  .wr_in(rtc_wr_in),

  .addr_out(RTCaddr),
  .data_out(rtc_dout),
  .wr_out(rtc_wr_out)
);

endmodule : save_handler