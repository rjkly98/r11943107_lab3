`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2023 10:38:55 AM
// Design Name: 
// Module Name: fir_tb
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
module bram11 
(
    CLK,
    WE,
    EN,
    Di,
    Do,
    A
);

    input   wire            CLK;
    input   wire    [3:0]   WE;
    input   wire            EN;
    input   wire    [31:0]  Di;
    output  wire    [31:0]  Do;
    input   wire    [11:0]   A; 

    //  11 words
	reg [31:0] RAM[0:10];
    reg [11:0] r_A;

    always @(posedge CLK) begin
        r_A <= A;
    end


    assign Do = {32{EN}} & RAM[r_A>>2];    // read


    // reg [31:0] Temp_D;
    always @(posedge CLK) begin
        if(EN) begin
	        if(WE[0]) RAM[A>>2][7:0]   <= Di[7:0];
            if(WE[1]) RAM[A>>2][15:8]  <= Di[15:8];
            if(WE[2]) RAM[A>>2][23:16] <= Di[23:16];
            if(WE[3]) RAM[A>>2][31:24] <= Di[31:24];
        end
    end
endmodule

module fir_tb
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter Data_Num    = 600
)();
    wire                        awready;
    wire                        wready;
    reg                         awvalid;
    reg   [(pADDR_WIDTH-1): 0]  awaddr;
    reg                         wvalid;
    reg signed [(pDATA_WIDTH-1) : 0] wdata;
    wire                        arready;
    reg                         rready;
    reg                         arvalid;
    reg         [(pADDR_WIDTH-1): 0] araddr;
    wire                        rvalid;
    wire signed [(pDATA_WIDTH-1): 0] rdata;
    reg                         ss_tvalid;
    reg signed [(pDATA_WIDTH-1) : 0] ss_tdata;
    reg                         ss_tlast;
    wire                        ss_tready;
    reg                         sm_tready;
    wire                        sm_tvalid;
    wire signed [(pDATA_WIDTH-1) : 0] sm_tdata;
    wire                        sm_tlast;
    reg                         axis_clk;
    reg                         axis_rst_n;

// ram for tap
    wire [3:0]               tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;

// ram for data RAM
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;



    fir fir_DUT(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        // ram for tap
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        // ram for data
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)

        );
    
    // RAM for tap
    bram11 tap_RAM (
        .CLK(axis_clk),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .A(tap_A),
        .Do(tap_Do)
    );

    // RAM for data: choose bram11 or bram12
    bram11 data_RAM(
        .CLK(axis_clk),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .A(data_A),
        .Do(data_Do)
    );
    

    reg signed [(pDATA_WIDTH-1):0] Din_list[0:(Data_Num-1)];
    reg signed [(pDATA_WIDTH-1):0] golden_list[0:(Data_Num-1)];
    integer dumpidx;
    initial begin
        $dumpfile("fir.vcd");
        $dumpvars();
        // dump the array variables manually in icarus
        // for (dumpidx = 0; dumpidx <= 10; dumpidx = dumpidx + 1) begin $dumpvars(0,coef[dumpidx]);end
        // for (dumpidx = 0; dumpidx < Data_Num; dumpidx = dumpidx + 1)begin $dumpvars(0,Din_list[dumpidx]);end
    end


    // initial begin //clock
    //     axis_clk = 0;
    //     forever begin
    //         #5 axis_clk = (~axis_clk);
    //     end
    // end

    initial begin //reset
        axis_clk = 0;
        axis_rst_n = 1;
        #(3.0);	    
        axis_rst_n = 0;
        #(5.0);	  
        axis_rst_n = 1;
        #(3.0);	  
        forever begin
            #5 axis_clk = (~axis_clk);
        end
    end

    reg [31:0]  data_length;  //load input and golden in tb
    integer Din, golden, input_data, golden_data, m;
    initial begin //ok
        data_length = 0;
        Din = $fopen("./samples_triangular_wave.dat","r");
        golden = $fopen("./out_gold.dat","r");
        for(m=0;m<Data_Num;m=m+1) begin
            input_data = $fscanf(Din,"%d", Din_list[m]);
            golden_data = $fscanf(golden,"%d", golden_list[m]);
            data_length = data_length + 1;
        end
    end

    integer i;
    initial begin // data inputs
        $display("------------Start simulation-----------");
        ss_tvalid = 0;
        $display("----Start the data input(AXI-Stream)----");
        for(i=0;i<(data_length-1);i=i+1) begin
            ss_tlast = 0; ss(Din_list[i]);
        end
        $display("----Done data input(AXI-Stream)----");
        $display("---- Start Config Read check (ap_idle)----");
        config_read_check(12'h00, 32'h00, 32'h0000_000f); // check ap_idle = 0
        $display("---- Done Config Read checl (ap_idle)----");
        ss_tlast = 1; ss(Din_list[(Data_Num-1)]); //last input
        $display("------End the data input(AXI-Stream!) ------");
    end

    integer k;
    reg error;
    reg status_error;
    initial begin // check computation result ( input keep sending at the same time )
        error = 0; status_error = 0;
        sm_tready = 1;
        wait (sm_tvalid);
        for(k=0;k < data_length;k=k+1) begin
            sm(golden_list[k],k);
        end
        // all process done 
        $display("---- All transmit DONE,  Start Config Read check (ap_done )----");
        config_read_check(12'h00, 32'h02, 32'h0000_0002); // check ap_done = 1 (0x00 [bit 1])
        $display("---- Ap_done check pass,  Start Config Read check (ap_idle )----");
        config_read_check(12'h00, 32'h04, 32'h0000_0004); // check ap_idle = 1 (0x00 [bit 2])
        $display("---- Ap_done check pass,  Ap_idle check pass ----");
        if (error == 0 & error_coef == 0) begin
            $display("---------------------------------------------");
            $display("-----------Congratulations! Pass-------------");
        end
        else begin
            $display("--------Simulation Failed---------");
        end
        $finish;
    end

    
    integer timeout = (100000); // Prevent hang
    initial begin
        while(timeout > 0) begin //simulation process wouldnot take that long
            @(posedge axis_clk);
            timeout = timeout - 1;
        end
        $display($time, "  Simualtion Hang ....");
        $finish;
    end


    reg signed [31:0] coef[0:10]; // fill in coef 
    initial begin
        coef[0]  =  32'd0; //todo : here is 0
        coef[1]  = -32'd10;
        coef[2]  = -32'd9;
        coef[3]  =  32'd23;
        coef[4]  =  32'd56;
        coef[5]  =  32'd63;
        coef[6]  =  32'd56;
        coef[7]  =  32'd23;
        coef[8]  = -32'd9;
        coef[9]  = -32'd10;
        coef[10] =  32'd0; //todo : here is 0
    end

    reg error_coef;
    initial begin // write coeff into tap_RAM and check, them awake FIR using ap_start (ok)
        error_coef = 0;
        $display("----Start the coefficient input(AXI-lite)----");
        config_write(12'h10, data_length); //write data length
        for(k=0; k< Tape_Num; k=k+1) begin
            config_write(12'h20 + 4*k, coef[k]); //+4*k ?
        end
        // read-back and check
        $display(" Check Coefficient ...");
        for(k=0; k < Tape_Num; k=k+1) begin
            config_read_check(12'h20 + 4*k, coef[k], 32'hffffffff); //+4*k ?
        end
        // arvalid <= 0;
        $display(" Tape programming done ...");
        $display(" Start FIR");
        @(posedge axis_clk) config_write(12'h00, 32'h0000_0001);    // ap_start = 1
        // @(posedge axis_clk) config_read_check(12'h00,32'h0000_0001 ,32'hffff_ffff);    // check ap_start == 1
        $display("----End the coefficient input(AXI-lite)----");
    end

    task config_write;
        
        input [11:0]    addr;
        input [31:0]    data;
        begin
            // $display("  Configure Write");
            awvalid <= 0; wvalid <= 0;
            @(posedge axis_clk);
            awvalid <= 1; awaddr <= addr;
            wvalid  <= 1; wdata <= data;
            @(posedge axis_clk);
            while ( wready !== 1'b1 ) @(posedge axis_clk); //awready unused
            awvalid <= 0; wvalid <= 0;
        end
    endtask

    task config_read_check;
        input [11:0]        addr;
        input signed [31:0] exp_data;
        input [31:0]        mask;
        begin
            arvalid <= 0;
            @(posedge axis_clk);
            arvalid <= 1; araddr <= addr;
            rready <= 1;
            @(posedge axis_clk);
            while (rvalid !== 1'b1) @(posedge axis_clk);
            if( (rdata & mask) !== (exp_data & mask)) begin
                $display("ERROR Config: exp = %d, rdata = %d", exp_data, rdata);
                error_coef <= 1;
                $finish;
            end else begin
                $display("OK: exp = %d, rdata = %d", exp_data, rdata);
            end
            arvalid <= 0;
            rready <= 0;
        end
    endtask



    task ss; //ss: Testbench Sends data into the FIR filter. Use axi_stream.
        input  signed [31:0] in1;
        begin
            // $display("  SS input");
            ss_tvalid <= 1'b1;
            ss_tdata  <= in1;
            @(posedge axis_clk);
            // $display("ss_tready = %b", ss_tready);
            while (ss_tready !== 1'b1) begin // wait for FIR ss_tready
                @(posedge axis_clk);
                // $display(" waiting...");
            end
            
            // $display(" ss_tready ss done");
            // @(posedge axis_clk);
            ss_tvalid <= 0;
            ss_tdata  <= 0;
            @(posedge axis_clk);
        end
    endtask

    task sm; //sm: Receives data from the FIR filter and compares it to expected (golden) data.
        input  signed [31:0] in2; // golden data
        input         [31:0] pcnt; // pattern count
        begin
            sm_tready <= 1;
            @(posedge axis_clk) 
            // wait(sm_tvalid);
            while(sm_tvalid !== 1'b1) begin  @(posedge axis_clk); end

            if (sm_tdata !== in2) begin
                $display("[ERROR SM] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
                error <= 1;
                @(posedge axis_clk);
                $finish;
            end
            else begin
                $display("[PASS SM] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
            end
            @(posedge axis_clk);
        end
    endtask

endmodule

