`timescale 1ns / 1ns
module DriveTFT18(
  input wire clk,
  input wire rsth,
  output wire SCL,
  output wire WRX,
  output wire RESX,
  output wire CSX,
  inout  wire SDA,
  output wire UART_TX,
  output wire [6:0] LED
);

  wire [24:0] w_mcs_gpo;
  wire [31:0] w_rdata;
  wire        w_req           = w_mcs_gpo[24];
  wire [1:0]  w_mod_sel       = w_mcs_gpo[23:22];
  wire [3:0]  w_spi_command   = w_mcs_gpo[21:18];
  wire [17:0] w_wdata         = w_mcs_gpo[17:0];


  // モジュールセレクトデコード
  // SPI select
  wire w_sel_spi      = (w_mod_sel == 2'b00);
  wire w_sel_tft_rst  = (w_mod_sel == 2'b11);
  wire w_sel_timer    = (w_mod_sel == 2'b01);

  // ACK
  wire w_ack_spi, w_ack_wait;
  wire w_ack_all = w_ack_spi & w_ack_wait;

  mcs mcs_0 (
    .Clk(clk), // input Clk
    .Reset(rsth), // input Reset
    .UART_Tx(UART_TX), // output UART_Tx
    .GPO1(w_mcs_gpo), // output [26 : 0] GPO1
    .GPI1(w_ack_all), // input [0 : 0] GPI1
    .GPI1_Interrupt(), // output GPI1_Interrupt
    .GPI2(w_rdata), // input [31 : 0] GPI2
    .GPI2_Interrupt() // output GPI2_Interrupt
  );

  // SPI
  spi spi (
    .clk(clk),
    .rsth(rsth),
    .mod_sel(w_sel_spi),
    .req(w_req),
    .command(w_spi_command),
    .wdata(w_wdata),
    .rdata(w_rdata),
    .ack(w_ack_spi),
    .oSCL(SCL),
    .oDCX(WRX),
    .oCSX(CSX),
    .oSDA(SDA)
  );

  // TFT リセット
  reg r_rstn;
  always @(posedge clk) begin
    if(rsth)          r_rstn <= 1'b0;
    if(w_sel_tft_rst) r_rstn <= w_wdata[0];
  end

  // wait
  timer_wait timer_wait (
    .clk(clk),
    .rsth(rsth),
    .mod_sel(w_sel_timer),
    .req(w_req),
    .w_wdata(w_wdata),
    .ack(w_ack_wait)
  );

  assign RESX = r_rstn;

  assign LED[6]   = SCL;
  assign LED[5]   = WRX;
  assign LED[4]   = CSX;
  assign LED[3]   = SDA;
  assign LED[2]   = w_req;
  assign LED[1]   = w_ack_spi;
  assign LED[0]   = w_ack_wait;

//assign LED[6:1] = {w_mod_sel[1:0], w_req, w_sel_spi, w_sel_tft_rst, w_sel_timer};
//assign LED[0]   = RESX;

endmodule

