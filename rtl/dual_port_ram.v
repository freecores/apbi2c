//////////////////////////////////////////////////////////////////
////
////
//// 	TOP I2C BLOCK to I2C Core
////
////
////
//// This file is part of the APB to I2C project
////
//// http://www.opencores.org/cores/apbi2c/
////
////
////
//// Description
////
//// Implementation of APB IP core according to
////
//// apbi2c_spec IP core specification document.
////
////
////
//// To Do: Things are right here but always all block can suffer changes
////
////
////
////
////
//// Author(s): - Felipe Fernandes Da Costa, fefe2560@gmail.com
////		  Ronal Dario Celaya ,rcelaya.dario@gmail.com
////
///////////////////////////////////////////////////////////////// 
////
////
//// Copyright (C) 2009 Authors and OPENCORES.ORG
////
////
////
//// This source file may be used and distributed without
////
//// restriction provided that this copyright statement is not
////
//// removed from the file and that any derivative work contains
//// the original copyright notice and the associated disclaimer.
////
////
//// This source file is free software; you can redistribute it
////
//// and/or modify it under the terms of the GNU Lesser General
////
//// Public License as published by the Free Software Foundation;
//// either version 2.1 of the License, or (at your option) any
////
//// later version.
////
////
////
//// This source is distributed in the hope that it will be
////
//// useful, but WITHOUT ANY WARRANTY; without even the implied
////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
////
//// PURPOSE. See the GNU Lesser General Public License for more
//// details.
////
////
////
//// You should have received a copy of the GNU Lesser General
////
//// Public License along with this source; if not, download it
////
//// from http://www.opencores.org/lgpl.shtml
////
////
///////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
module dp_ram
#(	parameter integer DWIDTH = 32,
 	parameter integer AWIDTH = 4
)

(
	input clock, reset, wr_en, rd_en,
	input [DWIDTH-1:0] data_in,
	input [AWIDTH-1:0] wr_addr,
	output [DWIDTH-1:0] data_out,
	input [AWIDTH-1:0] rd_addr
);

	reg [DWIDTH-1:0] mem [0:2**AWIDTH-1];
	integer i;

	always @(posedge clock)
	begin
		if (reset)
		begin
			for (i = 0; i < 16; i = i + 1)
			begin
				mem[i] <= {DWIDTH{1'b0}};
			end
		end
		else
		begin
			if (wr_en)
			begin
				mem[wr_addr] <= data_in;
			end
		end
	end

	assign data_out = (rd_en)?mem[rd_addr]:mem[rd_addr];


endmodule
