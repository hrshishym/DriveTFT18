module timer_wait(
  input wire clk,
  input wire rstn,
  input wire mod_sel,
  input wire req,
  input wire [7:0] w_wdata,
  output wire ack
);

  wire        en_wait_countup;  // 1cnt = 1kHz = 50 * 1000 cyc @ 50MHz
  reg [15:0]  en_wait_cnt;      // 1`50000
  reg [7:0]   wait_cnt;
  reg         req_1d;
  wire        req_pe;

  // req—§‚¿ã‚ª‚è
  always @(posedge clk) begin
    if(~rstn) req_1d <= 0;
    else      req_1d <= req;
  end

  assign req_pe = (mod_sel) & (req & ~req_1d);

  always @(posedge clk) begin
    if(~rstn) en_wait_cnt <= 49999;
    else if(en_wait_cnt == 0) en_wait_cnt <= 49999;
    else                      en_wait_cnt <= en_wait_cnt - 1;
  end
  assign en_wait_countup = (en_wait_cnt == 0);

  always @(posedge clk) begin
    if(~rstn) wait_cnt <= 0;
    else if(req_pe)           wait_cnt <= w_wdata;
    else if(wait_cnt == 0)    wait_cnt <= wait_cnt;
    else if(en_wait_countup)  wait_cnt <= wait_cnt - 1;
  end

  assign ack = (wait_cnt == 0);

endmodule

