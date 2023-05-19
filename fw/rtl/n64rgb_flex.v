//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the N64 RGB/YPbPr DAC project.
//
// Copyright (C) 2015-2022 by Peter Bartmann <borti4938@gmail.com>
//
// N64 RGB/YPbPr DAC is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//////////////////////////////////////////////////////////////////////////////////
//
// Company:  Circuit-Board.de
// Engineer: borti4938
//
// Module Name:    n64rgb_flex
// Project Name:   N64 RGB on Flex-PCB
//
// Note of authorship / special thanks to:
// !!! Special thanks go to ikari_01 / mrehkopf !!!
// Algorithm for NTSC/PAL detection and corresponding blanking phase decision
// in VI-deblur mode originate from his source code:
// https://github.com/mrehkopf/n64rgb/blob/master/n64rgb_buffered/n64rgb_buffered.v
//
//////////////////////////////////////////////////////////////////////////////////

`define USE_POSEDGE_VCLK

module n64rgb_flex(
  VCLK_i,
  nDSYNC_i,
  D_i,
  nViDeBlur_i,
  R_o,
  G_o,
  B_o,
  nCSYNC_o
);

input VCLK_i;
input nDSYNC_i;
input [6:0] D_i;
input nViDeBlur_i;
output reg [6:0] R_o;
output reg [6:0] G_o;
output reg [6:0] B_o;
output reg nCSYNC_o;


// wires
wire VCLK_w;
wire negedge_nVSYNC_w, negedge_nHSYNC_w, posedge_nCSYNC_w;

//regs
reg [3:0] SYNC_L;
reg [6:0] R_L [0:1];
reg [6:0] G_L [0:1];
reg [6:0] B_L [0:1];

reg [1:0] line_cnt = 2'b00; // PAL: line_cnt[1:0] == 0x ; NTSC: line_cnt[1:0] = 1x
reg        palmode = 1'b0;  // PAL: palmode == 1        ; NTSC: palmode == 0

reg field_id, n64_480i;

reg [1:0] phase_cnt = 2'b00;
reg nblank_vdata;

// rtl
`ifdef USE_POSEDGE_VCLK
  assign VCLK_w = VCLK_i;
`else
  assign VCLK_w = ~VCLK_i;
`endif

assign negedge_nVSYNC_w =  SYNC_L[3] & !D_i[3];
assign negedge_nHSYNC_w =  SYNC_L[1] & !D_i[1];
assign posedge_nCSYNC_w = !SYNC_L[0] &  D_i[0];


always @(posedge VCLK_w)
  if (!nDSYNC_i) begin
    if(negedge_nVSYNC_w) begin // posedge at nVSYNC detected - reset line_cnt and set palmode
      line_cnt <= 2'b00;
      palmode <= ~line_cnt[1];
    end else if (negedge_nHSYNC_w) begin  // posedge nHSYNC -> increase line_cnt
      line_cnt <= line_cnt + 1'b1;
    end
  end
  
always @(posedge VCLK_w)
  if (!nDSYNC_i) begin
    if (negedge_nVSYNC_w) begin                 // negedge at nVSYNC
      field_id <= negedge_nHSYNC_w;             // if negedge at nHSYNC too, then odd field, otherwise even field
      n64_480i <= field_id ^ negedge_nHSYNC_w;  // n64_480i becomes high if field_id changes, otherwise it stays zero
    end
  end
  
always @(posedge VCLK_w)
  if (!nDSYNC_i) begin
    if (nViDeBlur_i | n64_480i) begin
      nblank_vdata <= 1'b1;
    end else begin
      if(posedge_nCSYNC_w) // posedge nCSYNC -> reset blanking
        nblank_vdata <= palmode;
      else
        nblank_vdata <= ~nblank_vdata;
    end
  end

always @(posedge VCLK_w)
  if (!nDSYNC_i) begin
    phase_cnt <= 2'b00;
    SYNC_L <= D_i[3:0];
    if (nblank_vdata) begin
      R_L[1] <= R_L[0];
      G_L[1] <= G_L[0];
      B_L[1] <= B_L[0];
    end
  end else begin
    casez(phase_cnt)
      2'b00: R_L[0] <= D_i;
      2'b01: G_L[0] <= D_i;
      2'b10: B_L[0] <= D_i;
    endcase
    phase_cnt <= phase_cnt + 2'b01;
  end

always @(SYNC_L,R_L[1],G_L[1],B_L[1]) begin
  nCSYNC_o <= SYNC_L[0];
  {R_o,G_o,B_o} <= {R_L[1],G_L[1],B_L[1]};
end

endmodule
