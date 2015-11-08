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
  reg         req;      // H:request
  reg         rw;       // H:read L:write
  reg         dcx;      // H:data  L:command
  reg [7:0]   wdata;    // 
  reg [1:0]   readsize; // 
  reg         mod_sel;  // 
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
    .rw(rw),
    .dcx(dcx),
    .wdata(wdata),
    .readsize(readsize),
    .rdata(rdata),
    .ack(ack),
    .oSCL(oSCL),
    .oDCX(oDCX),
    .oCSX(oCSX),
    .oSDA(oSDA)
  );

  always #10 clk = ~clk;

  initial begin
    clk  = 0;
    rsth = 1;
    mod_sel = 0;
    req  = 0;
    rw   = 0;
    dcx  = 0;
    wdata = 0;
    readsize = 0;
    repeat (10) @(posedge clk);
    rsth = 0;
    repeat (10) @(posedge clk);

    // 書き込み (Command)
    mod_sel <= 1'b1;
    req <= 1'b1;
    rw  <= 1'b0;
    dcx <= 1'b0;
    wdata <= 8'b11001010;
    
    repeat(20) @(posedge clk);
    wait(ack == 1'b1);

    #100;

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 書き込み (Command)
    mod_sel <= 1'b1;
    req <= 1'b1;
    rw  <= 1'b0;
    dcx <= 1'b0;
    wdata <= 8'ha5;
    
    repeat(20) @(posedge clk);
    wait(ack == 1'b1);

    #100;

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 書き込み (Data)
    mod_sel <= 1'b1;
    req <= 1'b1;
    rw  <= 1'b0;
    dcx <= 1'b1;
    wdata <= 8'b11101100;
    
    repeat(20) @(posedge clk);
    wait(ack == 1'b1);

    #100;

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 読み出し
    read_data = 'h12;
    mod_sel <= 1'b1;
    req <= 1'b1;
    rw  <= 1'b1;
    dcx <= 1'b0;
    wdata <= 8'b00110101;
    
    repeat(10) @(posedge clk);
    wait(ack == 1'b1);

    req <= 1'b0;
    repeat(10) @(posedge clk);

    // 読み出し
    read_data = 'h12345678;
    mod_sel <= 1'b1;
    rw  <= 1'b1;
    dcx <= 1'b0;
    readsize <= 2'b11;  // 32bit
    wdata <= 8'b10100011;
    req <= 1'b1;
    
    repeat(10) @(posedge clk);
    wait(ack == 1'b1);

    req <= 1'b0;
    repeat(8 * 10) @(posedge clk);

    #100;
    $finish;
  end

  reg [5:0] read_pos = 6'b11_1111;
  reg req_1d;
  always @(negedge oSCL) begin
    req_1d <= req;
  end
  wire req_pe = ~req_1d & req;
  always @(negedge oSCL or posedge req) begin
    if(rsth)                        read_pos = 6'b11_1111;
    else if(rw & req_pe)            read_pos = readsize * 8 + 8;
    else if(read_pos == 6'b11_1111) read_pos = -1;
    else if(oCSX)                   read_pos = read_pos - 1;
  end

  always @(negedge oSCL) begin
    if(read_pos == 6'b11_1111) r_SDA = 1'bz;
    else                       r_SDA = read_data[read_pos];
  end


endmodule
