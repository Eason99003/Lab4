//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output reg wbs_ack_o,
    output reg [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    
    wire        awready;      // driven by fir_DUT
    wire        wready;       // driven by fir_DUT
    reg         awvalid;      // driven by your AXI-Lite master logic
    reg  [11:0] awaddr;       // ""
    reg         wvalid;       // ""
    reg  [31:0] wdata;        // ""
    wire        arready;      // driven by fir_DUT
    reg         rready;       // driven by your AXI-Lite master logic
    reg         arvalid;      // ""
    reg  [11:0] araddr;       // ""
    wire        rvalid;       // driven by fir_DUT
    wire [31:0] rdata;        // driven by fir_DUT
    reg         ss_tvalid;    // your AXI-Stream-in logic
    reg [31:0]  ss_tdata;      // ""
    wire        ss_tready;    // driven by fir_DUT
    reg         sm_tready;    // your AXI-Stream-out logic
    wire        sm_tvalid;    // driven by fir_DUT
    wire [31:0] sm_tdata;     // driven by fir_DUT

    wire axis_clk = wb_clk_i;
    wire axis_rst_n = ~wb_rst_i;

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
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)
    );

    // interface of user bram and wb 
    reg [3:0] rd_delay;
    reg [31:0] bram_dat_r;
    reg bram_ack_rw;
    reg bram_cs;
    reg [3:0] bram_we;
    reg [31:0] bram_addr;
    reg [31:0] bram_din;
    wire [31:0] bram_raw_dout;

    localparam ADDR_BITS = 10;
    wire clk;
    wire rst;

    bram user_bram (
        .CLK(clk),
        .WE0(bram_we),
        .EN0(bram_cs),
        .Di0(bram_din),
        .Do0(bram_raw_dout),
        .A0(bram_addr)
    );


    reg axi_ack_w;
    reg aw_finish;

    reg axi_ack_r;
    reg [31:0] axi_dat_r;
    reg ar_finish;


    reg ss_tdata_ack;

    reg y_dat_ack;


    assign clk = wb_clk_i;
    assign rst = wb_rst_i;
     
    // AXI_LITE-WB (Write)
    always @(posedge axis_clk) begin
        if (~axis_rst_n) begin
            awvalid <= 0;
            awaddr <= 12'b0;
            aw_finish <= 0;
            wvalid <= 0;
            wdata <= 32'b0;
            axi_ack_w <= 0;
        end else if (wbs_cyc_i && wbs_stb_i && wbs_we_i && (wbs_adr_i[31:24] == 8'h30) && (axi_ack_w == 0) &&
            ((8'h18 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h10) || (8'hA8 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h80) ||
            (wbs_adr_i[7:0] == 8'h00))) begin
            awvalid <= ((aw_finish == 0) && (~awvalid || ~awready)) ? 1 : 0;
            awaddr <= ((aw_finish == 0) && (~awvalid || ~awready)) ? wbs_adr_i[11:0] : 12'b0;
            aw_finish <= (awvalid && awready) ? 1 : aw_finish; 
            wvalid <= ((aw_finish == 1 && (~wvalid || ~wready))) ? 1 : 0;
            wdata <= ((aw_finish == 1 && (~wvalid || ~wready))) ? wbs_dat_i : 32'b0;
            axi_ack_w <= (wvalid && wready) ? 1 : 0;
        end else begin
            awvalid <= 0;
            awaddr <= 12'b0;
            aw_finish <= 0;
            wvalid <= 0;
            wdata <= 32'b0;
            axi_ack_w <= 0;
        end
    end

    // AXI_LITE-WB (Read)
    always @(posedge axis_clk) begin
        if (~axis_rst_n) begin
            arvalid <= 0;
            araddr <= 12'b0;
            ar_finish <= 0;
            rready <= 0;
            axi_dat_r <= 32'b0;
            axi_ack_r <= 0;
        end else if (wbs_cyc_i && wbs_stb_i && ~wbs_we_i && (wbs_adr_i[31:24] == 8'h30) && (axi_ack_r == 0) &&
            ((8'h18 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h10) || (8'hA8 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h80) || 
            (wbs_adr_i[7:0] == 8'h00))) begin
            arvalid <= (ar_finish == 0 & (~arvalid | ~arready)) ? 1 : 0;
            araddr <= (ar_finish == 0 & (~arvalid | ~arready)) ? wbs_adr_i[11:0] : 12'b0;
            ar_finish <= (arvalid & arready) ? 1 : ar_finish;
            rready <= (ar_finish == 1 & (~rready | ~rvalid)) ? 1 : 0;
            axi_dat_r <= (rready & rvalid) ? rdata : 32'b0;
            axi_ack_r <= (rready & rvalid) ? 1 : 0;
        end else begin
            arvalid <= 0;
            araddr <= 12'b0;
            ar_finish <= 0;
            rready <= 0;
            axi_dat_r <= 32'b0;
            axi_ack_r <= 0;
        end
    end

    // AXI_Stream-WB (Xin)    
    always @(posedge axis_clk) begin
        if (~axis_rst_n) begin
            ss_tdata <= 32'b0;
            ss_tvalid <= 0;
            ss_tdata_ack <= 0;
        end else if (wbs_cyc_i && wbs_stb_i && wbs_we_i && (wbs_adr_i[31:24] == 8'h30) && ~ss_tdata_ack &&
            (wbs_adr_i[7:0] == 8'h40)) begin
            ss_tdata <= wbs_dat_i;
            ss_tvalid <= (~ss_tvalid || ~ss_tready);
            ss_tdata_ack <= (ss_tvalid == 1 && ss_tready == 1) ? 1 : 0;
        end else begin
            ss_tdata <= 32'b0;
            ss_tvalid <= 0;
            ss_tdata_ack <= 0;
        end
    end

    // AXI_Stream-WB (Yout)
    always @(posedge axis_clk) begin
        if (~axis_rst_n) begin
            sm_tready <= 0;
        end else if (wbs_cyc_i && wbs_stb_i && ~wbs_we_i && (wbs_adr_i[31:24] == 8'h30) && ~y_dat_ack &&
            (wbs_adr_i[7:0] == 8'h44)) begin
            sm_tready <= (~sm_tready || ~sm_tvalid);
        end else begin 
            sm_tready <= 0;
        end
    end

    always @* begin
        if (sm_tready & sm_tvalid) y_dat_ack = 1;
        else y_dat_ack = 0;
    end



    // bram-WB
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset all regs
            bram_cs     <= 1'b0;
            bram_we     <= 4'b0;
            bram_addr   <= {ADDR_BITS{1'b0}};
            bram_din    <= 32'b0;
            rd_delay    <= 4'd0;
            bram_dat_r  <= 32'b0;
            bram_ack_rw <= 1'b0;
        end else begin
            // start a new cycle if WB access to 0x38 region
            if (wbs_cyc_i && wbs_stb_i && (wbs_adr_i[31:24] == 8'h38)) begin
                bram_cs   <= 1'b1;
                bram_addr <= wbs_adr_i[ADDR_BITS+1:2]; // align down to word
                rd_delay <= (rd_delay == DELAYS[3:0]) ? 4'd0 : rd_delay + 1;
                bram_we  <= (wbs_we_i == 1) ? wbs_sel_i : 4'b0;
                bram_din <= (wbs_we_i == 1) ? wbs_dat_i : 32'b0;
                bram_dat_r  <= (rd_delay == DELAYS[3:0]) ? bram_raw_dout : 32'b0;
                bram_ack_rw <= (rd_delay == DELAYS[3:0]) ? 1'b1 : 1'b0;
            end else begin
                bram_cs     <= 1'b0;
                bram_we     <= 4'b0;
                bram_din    <= 32'b0;
                bram_addr   <= bram_addr;  // hold address unless overwritten
                bram_ack_rw <= 1'b0;
                rd_delay <= 0;
                bram_dat_r <= 32'b0;
            end
        end
    end

    always @* begin
        if ((wbs_adr_i[31:24] == 8'h30) && wbs_cyc_i && wbs_stb_i) begin
            if (wbs_we_i && ((8'h18 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h10) || (8'hA8 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h80) || 
                (wbs_adr_i[7:0] == 8'h00))) begin
                wbs_ack_o = axi_ack_w;
                wbs_dat_o = 32'b0;
            end else if (~wbs_we_i && ((8'h18 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h10) || (8'hA8 >= wbs_adr_i[7:0] && wbs_adr_i[7:0] >= 8'h80))) begin
                wbs_ack_o = axi_ack_r;
                wbs_dat_o = axi_dat_r;
            end else if (~wbs_we_i && (wbs_adr_i[7:0] == 8'h00)) begin
                wbs_ack_o = axi_ack_r;
                wbs_dat_o = {26'b0, sm_tvalid, ss_tready, 1'b0, axi_dat_r[2:0]};
            end else if (wbs_we_i && (wbs_adr_i[7:0] == 8'h40)) begin
                wbs_ack_o = ss_tdata_ack;
                wbs_dat_o = 'hffff_ffff;
            end else if (~wbs_we_i && (wbs_adr_i[7:0] == 8'h44)) begin
                wbs_ack_o = y_dat_ack;
                wbs_dat_o = sm_tdata;
            end else begin
                wbs_ack_o = 0;
                wbs_dat_o = 32'b0;
            end
        end else if ((wbs_adr_i[31:24] == 8'h38) && wbs_cyc_i && wbs_stb_i) begin
            wbs_ack_o = bram_ack_rw;
            wbs_dat_o = bram_dat_r;
        end else begin
            wbs_ack_o = 0;
            wbs_dat_o = 32'b0;
        end
    end


    

    assign la_data_out = 128'b0;
    assign io_out = {`MPRJ_IO_PADS{1'b0}};
    assign io_oeb = {`MPRJ_IO_PADS{1'b1}};
    assign irq = 3'b000;



endmodule



`default_nettype wire
