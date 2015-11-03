module sim_wait_timer();

  reg         clk;
  reg         rstn;     // H:reset
  reg         mod_sel;
  reg         req;
  reg [7:0]   w_wdata;
  wire        ack;


  timer_wait uut (
    .clk(clk),
    .rstn(rstn),
    .mod_sel(mod_sel),
    .req(req),
    .w_wdata(w_wdata),
    .ack(ack)
  );

  always #10 clk = ~clk;

  initial begin
    clk = 0;
    rstn = 0;
    mod_sel = 0;
    req = 0;
    w_wdata = 0;

    repeat(10) @(posedge clk);
    rstn = 1;
    repeat(10) @(posedge clk);

    // 10ms ‘Ò‚Â
    w_wdata = 10;
    @(posedge clk);
    mod_sel <= 1;
    req <= 1;
    repeat(50 * 1000 * 11) @(posedge clk);

    $finish;
  end

endmodule

// vim: expandtab : sw=2 : ts=2:
