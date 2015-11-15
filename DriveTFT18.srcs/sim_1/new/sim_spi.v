`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2015/11/01 18:08:48
// Design Name: 
// Module Name: sim_spi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sim_spi(

    );
  reg         clk;
  reg         rsth;     // H:reset
  // MCSからの入力
  reg         mod_sel;  // 
  reg         req;      // H:request
  reg [3:0]   command;  // 
  reg [17:0]  wdata;    // 
  // MCSへの出力
  wire [31:0]  rdata;   // 
  wire         ack;     // H:ack
  // FPGA外への入出力
  wire         oSCL;     // 
  wire         oDCX;     // 
  wire         oCSX;     // 

  reg          r_SDA = 1'bz;  // 初期状態は出力
  wire         oSDA = r_SDA;     // 

  reg [31:0]    read_data = 0;

  spi uut (
    .clk(clk),
    .rsth(rsth),
    .mod_sel(mod_sel),
    .req(req),
    .command(command),
    .wdata(wdata),
    .rdata(rdata),
    .ack(ack),
    .oSCL(oSCL),
    .oDCX(oDCX),
    .oCSX(oCSX),
    .oSDA(oSDA)
  );

  always #10 clk = ~clk;


  integer testnum = 0;
  initial begin
    clk       = 0;
    rsth      = 1;
    mod_sel   = 0;
    req       = 0;
    command   = 0;
    wdata     = 0;
    repeat (10) @(posedge clk);
    rsth = 0;
    repeat (10) @(posedge clk);

    // 書き込み (Command)
    testnum = 1;
    mod_sel <= 1'b1;
    req <= 1'b1;
    command  <= 4'b0000;
    wdata <= 18'b11001010;
    
    repeat(20) @(posedge clk);
    wait(ack == 1'b1);

    #100;

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 書き込み (Command)
    testnum = 2;
    mod_sel <= 1'b1;
    req <= 1'b1;
    command <= 4'b0000;
    wdata <= 8'ha5;
    
    repeat(20) @(posedge clk);
    wait(ack == 1'b1);

    #100;

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 書き込み (Data)
    testnum = 3;
    mod_sel <= 1'b1;
    req <= 1'b1;
    command <= 4'b0001;
    wdata <= 8'b11101100;
    
    repeat(20) @(posedge clk);
    wait(ack == 1'b1);

    #100;

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 読み出し 8bit
    testnum = 4;
    read_data = 'h12;
    mod_sel <= 1'b1;
    req <= 1'b1;
    command <= 4'b0100;
    wdata <= 8'b00110101;
    
    repeat(10) @(posedge clk);
    wait(ack == 1'b1);

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 読み出し 32bit
    testnum = 5;
    read_data = 'h12345678;
    mod_sel <= 1'b1;
    command <= 4'b0111;
    wdata <= 8'b10100011;
    req <= 1'b1;
    
    repeat(10) @(posedge clk);
    wait(ack == 1'b1);

    req <= 1'b0;
    repeat(8 * 10) @(posedge clk);

    // 画素書き出しはじめ
    testnum = 6;
    mod_sel <= 1'b1;
    command <= 4'b1000;
    req <= 1'b1;
    repeat(100) @(posedge clk);
    req <= 1'b0;
    
    repeat(10) @(posedge clk);

    // 画素書き出し
    testnum = 7;
    mod_sel <= 1'b1;
    command <= 4'b1001;
    wdata   <= (6'b101010 << 12 ) | (6'b111000 << 6) | (6'b001101);
    req <= 1'b1;
    repeat(10) @(posedge clk);
    req <= 1'b0;
    wait(ack == 1'b1);
    req <= 1'b0;
    
    // 画素書き出し
    testnum = 8;
    mod_sel <= 1'b1;
    command <= 4'b1001;
    wdata   <= (6'b110011 << 12 ) | (6'b010101 << 6) | (6'b000111);
    req <= 1'b1;
    repeat(10) @(posedge clk);
    req <= 1'b0;
    wait(ack == 1'b1);
    repeat(10) @(posedge clk);
    
    // 画素書き出し終わり
    testnum = 9;
    mod_sel <= 1'b1;
    command <= 4'b1010;
    req <= 1'b1;
    repeat(10) @(posedge clk);
    req <= 1'b0;
    
    repeat(100) @(posedge clk);

    #100;
    $finish;
  end

  reg [5:0] read_pos = 6'b11_1111;
  reg req_1d;
  always @(negedge oSCL) begin
    req_1d <= req;
  end
  wire req_pe = ~req_1d & req;
  wire is_read_command = (command[3:2] == 2'b01);
  wire [1:0] readsize = command[1:0];
  always @(negedge oSCL or posedge req) begin
    if(rsth)                          read_pos = 6'b11_1111;
    else if(is_read_command & req_pe) read_pos = readsize * 8 + 8;
    else if(read_pos == 6'b11_1111)   read_pos = -1;
    else if(oCSX)                     read_pos = read_pos - 1;
  end

  always @(negedge oSCL) begin
    if(read_pos == 6'b11_1111) r_SDA = 1'bz;
    else                       r_SDA = read_data[read_pos];
  end


endmodule
