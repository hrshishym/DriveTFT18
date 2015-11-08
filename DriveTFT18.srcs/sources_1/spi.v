`timescale 1ns / 1ns
`default_nettype none

module spi(
  input  wire         clk,
  input  wire         rsth,     // H:reset
  // MCSからの入力
  input  wire         mod_sel,  // H:module select
  input  wire         req,      // H:request
  input  wire         rw,       // H:read L:write
  input  wire         dcx,      // H:data  L:command
  input  wire [7:0]   wdata,    // 
  input  wire [1:0]   readsize, // 
  // MCSへの出力
  output wire [31:0]  rdata,    // 
  output wire         ack,      // H:ack
  // FPGA外への入出力
  output wire         oSCL,     // 
  output wire         oDCX,     // 
  output wire         oCSX,     // 
  inout  wire         oSDA      // 
);

  // モジュールセレクトとreqをand
  wire mod_req = mod_sel & req;

  reg r_rw;
  reg r_dcx;
  reg [7:0] r_wdata;
  reg [1:0] r_readsize;
  reg [7:0] r_state;
  parameter S_IDLE  = 0;
  parameter S_WRITE = 1;
  parameter S_READ  = 2;
  parameter S_READ_DMY = 3;
  parameter S_END = 4;

  // SPIクロック生成
  // クロックは1ステート間で立ち上がり、立ち下がり
  // ・書き込み時は1SCL = 8cyc
  // =X=======X=======
  // ___|~~~|___|~~~|___
  // -0123456701234567
  // ・読み出しは1SCL = 16cyc
  // =X===============X===============
  // _____|~~~~~~~|_______|~~~~~~~|___
  // -0123456789ABCDEF0123456789ABCDEF
  //
  // SCLKカウンタのサイクル数(read:8cyc / write:4cyc)
  // SCLK立ち下げカウンタ数  (read:3cyc / write 1cyc)
  wire [4:0]  w_scl_cyc     = (r_rw) ? 5'd31 : 5'd15; // 
  wire [4:0]  w_scl_downcyc = (r_rw) ? 5'd24 : 5'd12; // 
  wire [4:0]  w_scl_upcyc   = (r_rw) ? 5'd8  : 5'd4; //

  reg [4:0] r_sclcnt;
  always @(posedge clk) begin
         if(rsth)                   r_sclcnt <= 5'd0;
    else if(r_sclcnt == w_scl_cyc)  r_sclcnt <= 5'd0;
    else                            r_sclcnt <= r_sclcnt + 5'd1;
  end
  reg r_scl;
  always @(posedge clk) begin
    if(rsth) r_scl <= 1'b0;
    else if(r_sclcnt == w_scl_downcyc)                        r_scl <= 1'b0;
    else if((r_sclcnt == w_scl_upcyc) && (r_state != S_IDLE)) r_scl <= 1'b1;
  end

  // 
  wire  w_en_state = (r_rw) ? (r_sclcnt == 5'd4) : (r_sclcnt == 5'd0);

  // req立ち上がり検知でパラメータ生成
  reg r_req;
  always @(posedge clk) begin
    if(rsth) r_req <= 1'b0;
    else     r_req <= mod_req;
  end
  wire  w_req_pe = ~r_req & mod_req;

  // reqで各種データをラッチ
  always @(posedge clk) begin
    if(rsth) begin
      r_rw        <= 1'b0;
      r_dcx       <= 1'b0;
      r_wdata     <= 8'd0;
      r_readsize  <= 2'b00;
    end
    else if(w_req_pe) begin
      r_rw        <= rw;
      r_dcx       <= dcx;
      r_wdata     <= wdata;
      r_readsize  <= readsize;
    end
  end

  // req立ち上がり検知の保持
  reg r_req_detected;
  always @(posedge clk) begin
    if(rsth) r_req_detected <= 1'b0;
    else if(w_req_pe) r_req_detected <= 1'b1;
    else if(r_state == S_END) r_req_detected <= 1'b0;
  end

  // ステートマシン
  // ステートの遷移は、read:1cycで、write:0cycで行う
  // 用意するステートは
  //  IDLE:
  //  WRITE:
  //  READ:
  reg [2:0] r_remain_transdata;
  reg [4:0] r_remain_read;

  always @(posedge clk) begin
    if(rsth) r_state <= S_IDLE;
    else if(w_en_state) begin
      case(r_state)
        S_IDLE: begin
          // reqが入力されたらもれなくWRITEステートに遷移
          if(r_req_detected) begin
            r_state <= S_WRITE;
          end
        end
        S_WRITE: begin
          // データ出力ステート
          // 残りの出力データ数が0になったら
          //  r_rw = 1の場合、READ_DMYステートに遷移
          //  r_rw = 0の場合、ENDステートに遷移
          if(r_remain_transdata == 3'd0) begin
            r_state <= (r_rw) ? ((r_readsize == 0) ? S_READ : S_READ_DMY) : S_END;
          end
        end
        S_READ_DMY: r_state <= S_READ;  // 何もしないでREADに遷移
        S_READ: begin
          // データ読み出しステート
          // 残りの読み出しデータ数が0になったらENDに遷移
          if(r_remain_read == 5'd0) r_state <= S_END;
        end
        S_END: begin
          r_state <= S_IDLE;
        end
        default: r_state <= S_IDLE;
      endcase
    end
  end

  // データ読み出し
  reg [31:0] r_rdata;

  always @(posedge clk) begin
    if(rsth) r_remain_read <= 5'd0;
    else if(w_en_state) begin
      if(r_state == S_IDLE)      r_remain_read <= (r_readsize * 8 + 5'd7);
      else if(r_state == S_READ) r_remain_read <= r_remain_read - 5'd1;
    end
  end

  always @(posedge clk) begin
    if(rsth) r_rdata <= 32'd0;
    else if((r_state == S_IDLE) && r_req_detected)  r_rdata <= 32'd0;
    else if(w_scl_upcyc) begin
      if(r_state == S_READ)                   r_rdata[r_remain_read] <= oSDA;
    end
  end

  // データ転送
  // SDA
  always @(posedge clk) begin
    if(rsth)  r_remain_transdata <= 3'd0;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && r_req_detected)    r_remain_transdata <= 3'd7;
      else if(r_remain_transdata == 3'd0) r_remain_transdata <= 3'd0;
      else                                r_remain_transdata <= r_remain_transdata - 3'd1;
    end
  end

  reg r_sda;
  reg [7:0] r_wdata_sda;
  always @(posedge clk) begin
    if(rsth) r_wdata_sda <= 8'd0;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && r_req_detected)  r_wdata_sda[6:0] <= {r_wdata[0], r_wdata[1], r_wdata[2], r_wdata[3],
                                                             r_wdata[4], r_wdata[5], r_wdata[6]};
      else if(r_state == S_WRITE)       r_wdata_sda[6:0] <= {1'b0, r_wdata_sda[6:1]};
    end
  end
  always @(posedge clk) begin
    if(rsth) r_sda <= 1'bz;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && r_req_detected)  r_sda <= r_wdata[7];      // 書き込みはMSBから
      else if(r_state == S_WRITE) begin
        if(r_remain_transdata == 3'd0)
          r_sda <= 1'bz;
        else
          r_sda <= r_wdata_sda[0];  // r_wdata_sdaはライトデータをMSB/LSB反転したもの
      end
    end
  end

  // CS
  // 書き込み時にアサート
  // 終了時にネゲート
  reg r_cs;
  always @(posedge clk) begin
    if(rsth) begin
      r_cs <= 1'b1;
    end
    else if(w_en_state) begin
      if((r_state == S_IDLE) && r_req_detected) begin
        r_cs <= 1'b0;
      end
      else if(~r_rw) begin // 書き込み時は書き込み完了でネゲート
        if((r_state == S_WRITE) && (r_remain_transdata == 3'd0)) begin
          r_cs <= 1'b1;
        end
      end
      else begin  // 読み出し時は読み出し完了でネゲート
        if((r_state == S_READ) && (r_remain_read == 5'd0)) begin
//    else begin  // 読み出し時はENDに遷移してからネゲート
//      if(r_state == S_END) begin
          r_cs <= 1'b1;
        end
      end
    end
  end
  
  // D/CX
  // 書き込み時にラッチしたdcxをアサート
  // 終了時にネゲート
  reg r_dcx_out;
  always @(posedge clk) begin
    if(rsth) begin
      r_dcx_out <= 1'b1;
    end
    else if(w_en_state) begin
      if((r_state == S_IDLE) && r_req_detected) begin
        r_dcx_out <= r_dcx;
      end
      else if((r_state == S_WRITE) && (r_remain_transdata == 3'd0)) begin
        r_dcx_out <= 1'b1;
      end
    end
  end

  // ACK
  //  ACKはREQでクリア、ステートが終了まで遷移したらアサート
  reg r_ack;
  always @(posedge clk) begin
    if(rsth)                    r_ack <= 1'b1;
    else if(w_req_pe)           r_ack <= 1'b0;
    else if(w_en_state) begin
      if(r_state == S_END)      r_ack <= 1'b1;
    end
  end


  // 出力
  assign rdata = r_rdata;
  assign ack   = r_ack;
  assign oSCL  = r_scl;
  assign oDCX  = r_dcx_out;
  assign oCSX  = r_cs;
  assign oSDA  = r_sda;

endmodule

`default_nettype wire
