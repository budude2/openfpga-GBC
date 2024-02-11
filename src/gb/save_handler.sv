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
  output logic [31:0]  sd_read_data,

  output logic [9:0]   datatable_addr,
  output logic         datatable_wren,
  output logic [31:0]  datatable_data,

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
  input logic          RTC_inuse
);

  assign bk_addr   = sd_buff_addr[17:1];
  assign bk_rtc_wr = bk_rtc_wr_int;
  assign bk_data   = bk_rtc_wr_int ? rtc_data[currRTCaddr[17:1]] : sd_buff_dout;

  logic [17:0] save_size_bytes;

  always @(posedge clk_74a or negedge pll_core_locked) begin
    if (~pll_core_locked) begin
      datatable_addr <= 0;
      datatable_data <= 0;
      datatable_wren <= 0;
    end else begin
      // Write sram size
      datatable_wren <= 1;

      if( RTC_inuse ) begin
        datatable_data <= save_size_bytes + 9;
      end else begin
        datatable_data <= save_size_bytes;
      end
      // Data slot index 1, not id 1
      datatable_addr <= 1 * 2 + 1;
    end
  end

  always_comb begin
    if (cart_has_save) begin
      case(ram_mask_file)
        8'h01 : save_size_bytes = 512;
        8'h03 : save_size_bytes = 2048;
        8'h0F : save_size_bytes = 8192;
        8'h3F : save_size_bytes = 32768;
        8'h7F : save_size_bytes = 65536;
        8'hFF : save_size_bytes = 131072;
        default : save_size_bytes = 0;
      endcase
    end else begin
      save_size_bytes = 0;
    end
  end

  wire [17:0] sd_buff_addr_in;
  wire [17:0] sd_buff_addr_out;
  wire [17:0] sd_buff_addr;

  always_comb begin
    if (bk_rtc_wr_int) begin
      sd_buff_addr = currRTCaddr;
    end else if (write_en) begin
      sd_buff_addr = sd_buff_addr_in;
    end else begin
      sd_buff_addr = sd_buff_addr_out;
    end
  end

  wire [15:0] sd_buff_din;
  wire [15:0] sd_buff_dout;
  wire rtc_wr, rtc_wr_old, write_en;
  reg bk_rtc_wr_int, rtc_loaded;

  always_comb begin
    if (sd_buff_addr_out >= save_size_bytes) begin
      case(sd_buff_addr_out[8:1])
        8'h00 : sd_buff_din = RTC_timestampOut[15:0];
        8'h01 : sd_buff_din = RTC_timestampOut[31:16];
        8'h02 : sd_buff_din = RTC_savedtimeOut[15:0];
        8'h03 : sd_buff_din = RTC_savedtimeOut[31:16];
        8'h04 : sd_buff_din = RTC_savedtimeOut[47:32];
        default  : sd_buff_din = 16'hFFFF;
      endcase
    end else begin
      sd_buff_din = bk_q;
    end
  end

  always_comb begin
    if (sd_buff_addr_in >= save_size_bytes) begin
      bk_wr  = 0;
      rtc_wr = write_en;
    end else begin
      bk_wr  = write_en;
      rtc_wr = 0;
    end
  end

  reg [15:0] rtc_data[5];

  always @(posedge clk_sys) begin
    rtc_wr_old <= rtc_wr;

    if(external_reset_s | cart_download) begin
      rtc_loaded <= 0;
    end
    else if(~rtc_wr_old & rtc_wr) begin
      rtc_loaded <= 1;
    end
    else begin
      rtc_loaded <= rtc_loaded;
    end
  end

  always @(posedge clk_sys) begin
    if(rtc_wr) begin
      rtc_data[sd_buff_addr_in[8:1]] <= sd_buff_dout;
    end
  end

  typedef enum {
    READ,
    WRITE,
    INC,
    STOP
  } stateType;

  stateType currState, nextState;

  wire [17:0] currRTCaddr, nextRTCaddr;

  always_ff @(posedge clk_sys) begin
    if(reset) begin
      currState <= READ;
      currRTCaddr <= 0;

    end else begin
      currState <= nextState;
      currRTCaddr <= nextRTCaddr;
    end
  end

  always_comb begin
    nextState = currState;
    nextRTCaddr = currRTCaddr;
    bk_rtc_wr_int = 0;

    case(currState)

      READ: begin
        if(rtc_loaded) begin
          nextState = WRITE;
        end
      end

      WRITE: begin
        bk_rtc_wr_int = 1;
        nextState = INC;
      end

      INC: begin
        nextRTCaddr = currRTCaddr + 2;

        if(nextRTCaddr < 10) begin
          nextState = READ;
        end else begin
          nextState = STOP;
        end
      end

      STOP: begin
        nextState = STOP;
      end
    endcase
  end

  data_unloader #(
    .ADDRESS_MASK_UPPER_4(4'h2),
    .ADDRESS_SIZE(18),
    .READ_MEM_CLOCK_DELAY(15),
    .INPUT_WORD_SIZE(2)
  ) save_data_unloader (
    .clk_74a(clk_74a),
    .clk_memory(clk_sys),

    .bridge_rd(bridge_rd),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_rd_data(sd_read_data),

    .read_en  (),
    .read_addr(sd_buff_addr_out),
    .read_data(sd_buff_din)
  );

  data_loader #(
    .ADDRESS_MASK_UPPER_4(4'h2),
    .ADDRESS_SIZE(18),
    .WRITE_MEM_CLOCK_DELAY(15),
    .WRITE_MEM_EN_CYCLE_LENGTH(3),
    .OUTPUT_WORD_SIZE(2)
  ) save_data_loader (
    .clk_74a(clk_74a),
    .clk_memory(clk_sys),

    .bridge_wr(bridge_wr),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_wr_data(bridge_wr_data),

    .write_en  (write_en),
    .write_addr(sd_buff_addr_in),
    .write_data(sd_buff_dout)
  );

endmodule : save_handler