`timescale 1ns / 1ns
`default_nettype none

module spi(
  input  wire         clk,
  input  wire         rsth,     // H:reset
  // MCS����̓���
  input  wire         mod_sel,  // H:module select
  input  wire         req,      // H:request
  input  wire         rw,       // H:read L:write
  input  wire         dcx,      // H:data  L:command
  input  wire [7:0]   wdata,    // 
  input  wire [1:0]   readsize, // 
  // MCS�ւ̏o��
  output wire [31:0]  rdata,    // 
  output wire         ack,      // H:ack
  // FPGA�O�ւ̓��o��
  output wire         oSCL,     // 
  output wire         oDCX,     // 
  output wire         oCSX,     // 
  inout  wire         oSDA      // 
);

  // ���W���[���Z���N�g��req��and
  wire mod_req = mod_sel & req;

  reg r_rw;
  reg r_dcx;
  reg [7:0] r_wdata;
  reg [1:0] r_readsize;

  // �N���b�N����
  // SCLK�J�E���^�̃T�C�N����(read:8cyc / write:4cyc)
  // SCLK���������J�E���^��  (read:3cyc / write 1cyc)
  wire [2:0]  w_scl_cyc     = (r_rw) ? 3'd7 : 3'd3; // 
  wire [2:0]  w_scl_downcyc = (r_rw) ? 3'd3 : 3'd1; // 

  // SPI�N���b�N����
  // req�����オ��ŃJ�E���^�N���A
  reg [2:0] r_sclcnt;
  always @(posedge clk) begin
         if(rsth)                   r_sclcnt <= 3'd0;
    else if(r_sclcnt == w_scl_cyc)  r_sclcnt <= 3'd0;
    else                            r_sclcnt <= r_sclcnt + 3'd1;
  end
  reg r_scl;
  always @(posedge clk) begin
    if(rsth) r_scl <= 1'b0;
    else if(r_sclcnt == w_scl_downcyc) r_scl <= 1'b0;
    else if(r_sclcnt == w_scl_cyc)     r_scl <= 1'b1;
  end

  // 
  wire  w_en_state = (r_rw) ? (r_sclcnt == 3'd1) : (r_sclcnt == 3'd0);

  // req�����オ�茟�m�Ńp�����[�^����
  reg r_req;
  always @(posedge clk) begin
    if(rsth)  r_req <= 1'b0;
    else if(w_en_state) r_req <= mod_req;
  end
  wire  w_req_pe = ~r_req & mod_req;

  // req�Ŋe��f�[�^�����b�`
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

  // �X�e�[�g�}�V��
  // �X�e�[�g�̑J�ڂ́Aread:1cyc�ŁAwrite:0cyc�ōs��
  // �p�ӂ���X�e�[�g��
  //  IDLE:
  //  WRITE:
  //  READ:
  reg [7:0] r_state;
  parameter S_IDLE  = 0;
  parameter S_WRITE = 1;
  parameter S_READ  = 2;
  parameter S_READ_DMY = 3;
  parameter S_END = 4;
  reg [2:0] r_remain_transdata;
  reg [4:0] r_remain_read;

  always @(posedge clk) begin
    if(rsth) r_state <= S_IDLE;
    else if(w_en_state) begin
      case(r_state)
        S_IDLE: begin
          // req�����͂��ꂽ�����Ȃ�WRITE�X�e�[�g�ɑJ��
          if(w_req_pe) begin
            r_state <= S_WRITE;
          end
        end
        S_WRITE: begin
          // �f�[�^�o�̓X�e�[�g
          // �c��̏o�̓f�[�^����0�ɂȂ�����
          //  r_rw = 1�̏ꍇ�AREAD_DMY�X�e�[�g�ɑJ��
          //  r_rw = 0�̏ꍇ�AEND�X�e�[�g�ɑJ��
          if(r_remain_transdata == 3'd0) begin
            r_state <= (r_rw) ? ((r_readsize == 0) ? S_READ : S_READ_DMY) : S_END;
          end
        end
        S_READ_DMY: r_state <= S_READ;  // �������Ȃ���READ�ɑJ��
        S_READ: begin
          // �f�[�^�ǂݏo���X�e�[�g
          // �c��̓ǂݏo���f�[�^����0�ɂȂ�����END�ɑJ��
          if(r_remain_read == 5'd0) r_state <= S_END;
        end
        S_END: begin
          r_state <= S_IDLE;
        end
        default: r_state <= S_IDLE;
      endcase
    end
  end

  // �f�[�^�ǂݏo��
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
    else if(r_state == S_READ) r_rdata[r_remain_read] <= oSDA;
  end

  // �f�[�^�]��
  // SDA
  always @(posedge clk) begin
    if(rsth)  r_remain_transdata <= 3'd0;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && w_req_pe)    r_remain_transdata <= 3'd7;
      else if(r_remain_transdata == 3'd0) r_remain_transdata <= 3'd0;
      else                                r_remain_transdata <= r_remain_transdata - 3'd1;
    end
  end

  reg r_sda;
  reg [7:0] r_wdata_sda;
  always @(posedge clk) begin
    if(rsth) r_wdata_sda <= 8'd0;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && w_req_pe)  r_wdata_sda[6:0] <= {r_wdata[0], r_wdata[1], r_wdata[2], r_wdata[3],
                                                             r_wdata[4], r_wdata[5], r_wdata[6]};
      else if(r_state == S_WRITE)       r_wdata_sda[6:0] <= {1'b0, r_wdata_sda[5:1]};
    end
  end
  always @(posedge clk) begin
    if(rsth) r_sda <= 1'bz;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && w_req_pe)  r_sda <= r_wdata[7];      // �������݂�MSB����
      else if(r_state == S_WRITE) begin
        if(r_remain_transdata == 3'd0)
          r_sda <= 1'bz;
        else
          r_sda <= r_wdata_sda[0];  // r_wdata_sda�̓��C�g�f�[�^��MSB/LSB���]��������
      end
    end
  end

  // CS
  // �������ݎ��ɃA�T�[�g
  // �I�����Ƀl�Q�[�g
  reg r_cs;
  always @(posedge clk) begin
    if(rsth) r_cs <= 1'b1;
    else if(w_en_state) begin
      if((r_state == S_IDLE) && w_req_pe) r_cs <= 1'b0;
      else if((r_state == S_WRITE) && (r_remain_transdata == 3'd0)) r_cs <= 1'b1;
    end
  end
  
  // D/CX
  // ��荞�񂾒l�����̂܂܏o�͂̂��߉������Ȃ�

  // ACK
  //  ACK��REQ�ŃN���A�A�X�e�[�g���I���܂őJ�ڂ�����A�T�[�g
  reg r_ack;
  always @(posedge clk) begin
    if(rsth)                    r_ack <= 1'b1;
    else if(w_req_pe)              r_ack <= 1'b0;
    else if(w_en_state) begin
      if(r_state == S_END)      r_ack <= 1'b1;
    end
  end


  // �o��
  assign rdata = r_rdata;
  assign ack   = r_ack;
  assign oSCL  = r_scl;
  assign oDCX  = r_dcx;
  assign oCSX  = r_cs;
  assign oSDA  = r_sda;

endmodule

`default_nettype wire