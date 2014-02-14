//////////////////////////////////////////////////////////////////
////
////
//// 	FIFO BLOCK to I2C Core
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
//// To Do: This block inst functional yet when you try only write half registers and it didnt go correctly FULL and EMPTY
////
////
////
////
////
//// Author(s): - Felipe Fernandes Da Costa, fefe2560@gmail.com
////		  Ronal Dario Celaya
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
module fifo
#(
	parameter integer DWIDTH = 32,
	parameter integer AWIDTH = 4
)

(
	input clock, reset, wr_en, rd_en,
	input [DWIDTH-1:0] data_in,
	output f_full, f_empty,
	output [DWIDTH-1:0] data_out
);


	reg [DWIDTH-1:0] mem [0:2**AWIDTH-1];

	reg [AWIDTH-1:0] wr_ptr;
	reg [AWIDTH-1:0] rd_ptr;
	reg [AWIDTH-1:0] last_position;

	reg last_was_write;

	always@(posedge clock)
	begin

		if (reset)
		//SYNCHRONOUS RESET
		begin
		rd_ptr <= {AWIDTH{1'b0}};
		wr_ptr <= {AWIDTH{1'b0}};
		last_position <= {AWIDTH{1'b0}};
		last_was_write <= 1'b1;

		// NONBLOCKING
		end
		else
		begin

			if(wr_en)//WRITE OPERATION
			begin
				mem[wr_ptr] <= data_in; //WRITE TO ARRAY
				wr_ptr <= wr_ptr + 11'd1;
				last_position <= last_position + 11'd1;
				
				last_was_write <= 1'b0; 

				rd_ptr <= {AWIDTH{1'b0}};

			end
			else if(rd_en)// READ OPERATION
			begin
				wr_ptr <= {AWIDTH{1'b0}};

				if(rd_ptr != {AWIDTH{1'b1}} && last_position == {AWIDTH{1'b0}})
				begin
					rd_ptr <= rd_ptr + 11'd1;
				end
				else if(rd_ptr != last_position)
				begin
					rd_ptr <= rd_ptr + 11'd1;
				end

				if(rd_ptr == last_position - 11'b1 || rd_ptr == {AWIDTH{1'b1}})
				begin
					last_was_write <= 1'b1; 
					last_position <= {AWIDTH{1'b0}};
				end
	
			end 			

		end

	end


	assign f_full = (!last_was_write | last_position != {AWIDTH{1'b0}} )? 1'b1:1'b0;
	assign f_empty = (last_was_write)? 1'b1:1'b0;
	assign data_out = mem[rd_ptr];//WRITE ON OUTPUT

endmodule
