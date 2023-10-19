
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     awvalid,
    output  reg                      awready, //awready unused in tb

    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  reg                      wready,

    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  reg                      arready, //arready ununsed in tb

    input   wire                     rready,
    output  reg                      rvalid,
    output  wire  [(pDATA_WIDTH-1):0] rdata,    

    input   wire                     ss_tvalid, // signal slave (?)
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  reg                      ss_tready, 

    input   wire                     sm_tready, 
    output  reg                      sm_tvalid, 
    output  reg  [(pDATA_WIDTH-1):0] sm_tdata, 
    output  reg                      sm_tlast, // unused in tb
    
    // bram for tap RAM
    output  reg  [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  reg  [(pDATA_WIDTH-1):0] tap_Di,
    output  reg  [(pADDR_WIDTH-1):0] tap_A,
    input   wire  [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  reg  [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  reg  [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);


// bram11 tap11(.CLK(axis_clk), .WE(tap_WE), .EN(tap_EN), .Di(tap_Di), .Do(tap_Do), .A(tap_A));
// bram11 data11(.CLK(axis_clk), .WE(data_WE), .EN(data_EN), .Di(data_Di), .Do(data_Do), .A(data_A));


reg apstart; 
reg apdone;
reg apidle;
reg[15:0] datalen;
wire[(pDATA_WIDTH-1):0] addr00;
assign addr00 = {29'b0,apidle,apdone,apstart};


always @(posedge axis_clk or negedge axis_rst_n) begin //apstart , apstartreg
    if(!axis_rst_n) begin
        apstart <= 0;
    end
    else begin
        if( awvalid==1'b1 && awaddr == 'h00 && apidle == 1'b1) begin //testbench program ap_start
            apstart <= 1'b1;
        end
        else begin
            apstart <= 1'b0;
        end
    end
end
always @(posedge axis_clk or negedge axis_rst_n) begin // apidle 
    if(!axis_rst_n) begin
        apidle <= 1;
    end
    else begin
        if(apstart == 1'b1) begin
            apidle <= 0;
        end
        else if(cs == S_TRANSM) begin
            if(sm_tlast == 1'b1 && ss_tlast == 1'b1 && sm_tvalid ) begin //transmit last signal
                apidle <= 1'b1;
            end
            else begin
                apidle <= apidle;
            end
        end
        else begin
            apidle <= apidle;
        end
    end
end
always @(posedge axis_clk or negedge axis_rst_n) begin // apdone
    if(!axis_rst_n) begin
        apdone <= 0;
    end
    else begin
        if(cs == S_TRANSM) begin
            if(sm_tlast == 1'b1 && ss_tlast == 1'b1 && sm_tvalid ) begin //transmit last signal
                apdone <= 1'b1;
            end
            else begin
                apdone <= apdone; //todo: apdone hang at 1
            end
        end
        else begin
            apdone <= apdone;
        end
    end
end

//FSM parameter
reg [3:0] cs ,ns ;
parameter S_IDLE = 0;
parameter S_COEFF = 1;
parameter S_CAL = 2;
parameter S_GETNXT = 3;
parameter S_TRANSM = 4;

always@(posedge axis_clk or negedge axis_rst_n)begin //FSM logic: cs logic
	if(!axis_rst_n)begin
		cs <= S_IDLE;
	end
	else begin
		cs <= ns;
	end
end
always@(*) begin //FSM logic: ns logic
	if(!axis_rst_n)begin
		ns = S_IDLE;
	end
	else begin
		case(cs)
			S_IDLE:begin
				ns = S_COEFF;
			end
			S_COEFF:begin
				if(apstart == 1)
					ns = S_GETNXT ;
				else
					ns = cs;
			end
			S_CAL: begin
                if(windowcnt == 11) begin
                    ns = S_TRANSM;
                end
                else begin
				    ns = cs;
                end
			end
            S_GETNXT: begin
                if(ss_tvalid == 1'b1 && ss_tready == 1'b1)begin
                    ns = S_CAL;
                end
                else begin
                    ns = cs;
                end
            end
            S_TRANSM : begin
                if(sm_tvalid == 1'b1 && sm_tready == 1'b1) begin
                    ns = S_GETNXT;
                end 
                else begin
                    ns = cs;
                end
            end
			default:
				ns = cs;
		endcase 
	end
end



// AXI-lite logic ( configure write ) ( input: awvalid, awaddr, wvalid, wdata output: wready)
// reg [(pADDR_WIDTH-1):0] addr_tmp;
// reg [(pDATA_WIDTH-1):0] wdata_tmp;
reg [1:0] awflag;
always @(posedge axis_clk or negedge axis_rst_n) begin  //  wready , awflag
    if(!axis_rst_n) begin
        wready   <= 0;
        awflag   <= 0;
    end
    else begin
        if(cs == S_COEFF) begin
            if(awvalid) begin // in tb , awvalid and wvalid is always 1 and 0 at the same time (weird)
                wready   <= 1'b1;
                awflag   <= awflag + 1;                
            end
            else begin
                wready   <= 1'b0;
                awflag   <= 0;
            end
        end
        else begin
            wready   <= 1'b0;
            awflag   <= 0;
        end
    end
end
assign rdata = (araddr == 'h00 ) ? addr00 : tap_Do; 
reg [1:0] arflag ;
always @(posedge axis_clk or negedge axis_rst_n) begin  // rdata , arflag counter for rvalid
    if(!axis_rst_n) begin
        arflag  <= 0;
    end
    else begin
        // if(cs == S_COEFF) begin
        //     if(arvalid) begin // in tb , awvalid and wvalid is always 1 and 0 at the same time (weird)
        //         if(araddr == 'h00) begin
        //             arflag  <= arflag + 1;
        //         end
        //         else begin
        //             arflag  <= arflag + 1;
        //         end
                
        //     end
        //     else begin
        //         arflag  <= 0;
        //     end
        // end
        // else if (cs == S_CAL) begin
            if(arvalid) begin // in tb , awvalid and wvalid is always 1 and 0 at the same time (weird)
                if(araddr == 'h00) begin
                    arflag  <= arflag + 1;
                end
                else begin
                    arflag  <= arflag + 1;
                end
            end
        //     else begin
        //         arflag  <= 0;
        //     end
        // end
        else begin
            arflag  <= 0;
        end
    end
end
always @(posedge axis_clk or negedge axis_rst_n) begin  // rvalid
    if(!axis_rst_n) begin
        rvalid <= 1'b0;
    end
    else begin
        // if(cs == S_COEFF) begin 
        //     if(arvalid == 1'b1 && arflag==1) begin
        //         rvalid <= 1'b1;
        //     end 
        //     else begin
        //         rvalid <= 1'b0;
        //     end
        // end
        // else if (cs == S_CAL) begin
            if(arvalid == 1'b1 && arflag==1) begin
                rvalid <= 1'b1;
            end 
            else begin
                rvalid <= 1'b0;
            end
        // end
        // else begin
        //     rvalid <= 1'b0;
        // end
    end
end

// bram (tap)
assign tap_EN  = 1'b1;
always @(posedge axis_clk or negedge axis_rst_n) begin  // tap_A logic, tap_Di logic
    if(!axis_rst_n) begin
        tap_A <= 0;
        tap_Di <= 0;
    end
    else begin
        if(cs == S_COEFF) begin
            if(awvalid) begin
                tap_A <= awaddr < 'h20 ?  'h00 : awaddr - 'h20 ;
                tap_Di <= wdata;
            end
            else if(arvalid) begin // in tb , awvalid and wvalid is always 1 and 0 at the same time (weird)
                tap_A <= araddr < 'h20 ?  'h00 : araddr - 'h20 ;
                tap_Di <= tap_Di;
            end
            else begin
                tap_A <= tap_A;
                tap_Di <= tap_Di;
            end
        end
        else if(cs == S_CAL) begin //loop through all elements in tap_bram
            tap_A <= taploop10*4;
            tap_Di <= tap_Di;
        end
        else if (cs == S_TRANSM) begin
            tap_A <= 0;
            tap_Di <= tap_Di;
        end
        else begin
            tap_A <= tap_A;
            tap_Di <= tap_Di;
        end
    end
end
always @(posedge axis_clk or negedge axis_rst_n) begin // tap_WE
    if(!axis_rst_n) begin
        tap_WE <= 4'b0;
    end
    else begin
        if(cs == S_COEFF) begin 
            if(awvalid && awflag == 1 && awaddr >= 'h20 ) begin //write to bram 
                tap_WE <= 4'b1111;
            end
            else begin
                tap_WE <= 4'b0;
            end
        end
        else begin
            tap_WE <= 4'b0;
        end
    end
end

// tap calculation logic
reg [3:0] taploop10;
always @(posedge axis_clk or negedge axis_rst_n) begin // taploop10 logic
    if(!axis_rst_n) begin
        taploop10 <= 0;
    end
    else begin
        if(cs == S_CAL) begin
            if(taploop10 <= 9) begin
                taploop10 <= taploop10 + 1;
            end
            else if (taploop10 == 10) begin
                taploop10 <= taploop10 ;
            end
            else begin
                taploop10 <= 0;
            end
        end
        else begin
            taploop10 <= 0;
        end
    end
end

//=================================================================================
// AXI-stream logic (input : ss_tvalid,ss_tdata,ss_tlast ; output: ss_tready  )
//=================================================================================

reg [(pDATA_WIDTH-1):0] sstemp;
reg [3:0] dataidx;

always @(posedge axis_clk or negedge axis_rst_n) begin // ss_tready logic, sstemp logic
    if(!axis_rst_n) begin
        ss_tready <= 0;
        sstemp <= 0; // todo: modify here to 0
    end
    else begin
        if(cs == S_GETNXT) begin
            if(ss_tvalid) begin
                if(ss_tready == 0 ) begin //do handshake only one cycle. sstemp is correct when ss_tvalid == ss_tready
                    sstemp <= ss_tdata;
                    ss_tready <= 1'b1;
                end
                else begin
                    sstemp <= sstemp;
                    ss_tready <= 1'b0;
                end
            end
            else begin
                sstemp <= sstemp;
                ss_tready <= 1'b0;
            end
        end
        else begin
            sstemp <= sstemp;
            ss_tready <= 1'b0;
        end
    end
end

always @(posedge axis_clk or negedge axis_rst_n) begin //dataidx logic
    if(!axis_rst_n) begin
        dataidx <= 0;
    end
    else begin
        if(cs == S_COEFF) begin
            if(dataidx <= 10 && data_WE == 4'b1111) begin
                dataidx <= dataidx + 1; 
            end
            else if(addr00 == 5) begin //apstart (apstart = 1 and idle = 1 ==> 101)
                dataidx <= 0;
            end 
        end
        else if(cs == S_TRANSM )begin
            if(sm_tready == 1'b1 && sm_tvalid == 1'b1) begin
                if(dataidx == 10)begin
                    dataidx <= 0;
                end
                else begin
                    dataidx <= dataidx + 1;
                end
            end
        end

        else begin
            dataidx <= dataidx;
        end

    end
end
//=================================================================================
//                 bram (data_RAM)
//=================================================================================

assign data_EN  = 1'b1;         // data_EN
assign data_Di  = sstemp;       // data_Di
// assign data_A   = dataidx*4;  // data_A
always @(posedge axis_clk or negedge axis_rst_n) begin // data_WE logic
    if(!axis_rst_n) begin
        data_WE <= 4'b0;
    end
    else begin
        if(cs == S_COEFF) begin 
            if(data_A <= 'h28)begin
                data_WE <= 4'b1111;  
            end
            else begin
                data_WE <= 4'b0;  
            end
        end
        else if(cs == S_GETNXT) begin
            if(ss_tvalid == 1'b1 && ss_tready == 1'b0) begin //write one input to data_RAM
                data_WE <= 4'b1111;
            end
            else begin
                data_WE <= 4'b0;
            end
        end
        else begin
            data_WE <= 4'b0;
        end
    end
end

always @(posedge axis_clk or negedge axis_rst_n) begin  // data_A
    if(!axis_rst_n) begin
        data_A <= 4'b0;
    end
    else begin
        if(cs == S_COEFF ) begin
            data_A <= dataidx*4;
        end
        else if (cs == S_CAL) begin
            data_A <= dataloop10*4;
        end
        else if(cs == S_GETNXT ) begin
            data_A <= dataidx*4;
        end
        else begin
            data_A <= 0;
        end
    end

end

// data calculation logic
reg [3:0] dataloop10;
always @(posedge axis_clk or negedge axis_rst_n) begin // dataloop10 logic
    if(!axis_rst_n) begin
        dataloop10 <= 0;
    end
    else begin
        if(cs == S_CAL) begin
            if(dataloop10 > 0 ) begin
                dataloop10 <= dataloop10 - 1;
            end
            else if (dataloop10 == 0) begin
                dataloop10 <= 10 ;
            end
            else begin
                dataloop10 <= 0;
            end
        end
        else begin
            dataloop10 <= dataidx;
        end
    end
end

reg[3:0] windowcnt ;
always @(posedge axis_clk or negedge axis_rst_n) begin // windowcnt logic
    if(!axis_rst_n) begin
        windowcnt <= 0;
    end
    else begin
        if(cs == S_CAL) begin
            if(taploop10 == 1 ) begin
                windowcnt <= 1;
            end
            else if (windowcnt > 0 && windowcnt <= 10) begin
                windowcnt <= windowcnt + 1;
            end
            else begin
                windowcnt <= 0;
            end
        end
        else begin
            windowcnt <= 0;
        end
    end
end

reg[(pDATA_WIDTH-1):0] ans;
always @(posedge axis_clk or negedge axis_rst_n) begin // ans logic
    if(!axis_rst_n) begin
        ans <= 0;
    end
    else begin
        if(cs == S_CAL) begin
            if(windowcnt > 0) begin
                ans <= ans + (tap_Do * data_Do);
            end
            else begin
                ans <= 0;
            end
        end
        else if(cs == S_TRANSM) begin
            ans <= ans; 
        end
        else begin
            ans <= 0;
        end
    end
end

always @(posedge axis_clk or negedge axis_rst_n) begin // sm_tvalid logic , sm_tdata logic
    if(!axis_rst_n) begin
        sm_tdata <= 0;
        sm_tvalid <= 0;
    end
    else begin
        if(cs == S_TRANSM) begin
            if(sm_tready == 1'b1) begin
                if(sm_tvalid == 1'b0) begin
                    sm_tdata <= ans;
                    sm_tvalid <= 1'b1;
                end
                else begin
                    sm_tdata <= 0;
                    sm_tvalid <= 1'b0;
                end
            end
            else begin
                sm_tdata <= 0;
                sm_tvalid <= 0;
            end
        end
        else begin
            sm_tdata <= 0;
            sm_tvalid <= 0;
        end
    end
end 

always @(posedge axis_clk or negedge axis_rst_n) begin  //sm_tlast logic
    if(!axis_rst_n) begin
        sm_tlast <= 1'b0;
    end
    else begin
        if(cs == S_GETNXT) begin
            if(ss_tlast == 1'b1) begin
                sm_tlast <= 1'b1;
            end
        end
        else if (apdone == 1'b1) begin
            sm_tlast <= 1'b0;
        end
        else begin
            sm_tlast <= sm_tlast;
        end 
    end
end

endmodule



