module RTC_loader(
  input logic         clk_sys,
  input logic         reset,
  input logic         external_reset_s,

  input logic         cart_download,
  output logic        loading_done,
  input logic         RTC_valid,

  input logic  [4:0]  addr_in,
  input logic  [15:0] data_in,
  input logic         wr_in,

  output logic [16:0] addr_out,
  output logic [15:0] data_out,
  output logic        wr_out
);

  assign addr_out = currRTCaddr;

  logic wr_in_old, rtc_loaded;

  always @(posedge clk_sys) begin
    wr_in_old <= wr_in;

    if(external_reset_s | cart_download) begin
      rtc_loaded <= 0;
    end else if(~wr_in_old & wr_in) begin
      rtc_loaded <= 1;
    end else begin
      rtc_loaded <= rtc_loaded;
    end
  end

 typedef enum {
    READ,
    WAIT,
    WRITE,
    INC,
    STOP
  } stateType;

  stateType currState, nextState;
  logic [16:0] currRTCaddr, nextRTCaddr;

  always_ff @(posedge clk_sys) begin
    if(reset) begin
      currState   <= READ;
      currRTCaddr <= 0;

    end else begin
      currState   <= nextState;
      currRTCaddr <= nextRTCaddr;
    end
  end

  always_comb begin
    nextState     = currState;
    nextRTCaddr   = currRTCaddr;
    wr_out        = 0;
    loading_done  = 0;

    case(currState)

      READ: begin
        if(rtc_loaded & RTC_valid) begin
          nextState = WAIT;
        end else begin
          nextState = STOP;
        end
      end

      WAIT: begin
        nextState = WRITE;
      end

      WRITE: begin
        wr_out    = 1;
        nextState = INC;
      end

      INC: begin
        nextRTCaddr = currRTCaddr + 1;

        if(nextRTCaddr < 10) begin
          nextState = READ;
        end else begin
          nextState = STOP;
        end
      end

      STOP: begin
        loading_done = 1;
      end
    endcase
  end

  rtc_ram rtc_ram_inst (
    .clock      ( clk_sys ),
    .wraddress  ( addr_in ),
    .data       ( data_in ),
    .wren       ( wr_in ),

    .rdaddress  ( currRTCaddr ),
    .q          ( data_out ) // 1 cycle delay after address set
  );

endmodule