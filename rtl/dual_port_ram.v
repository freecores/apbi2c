`timescale 1ns/1ps
module dp_ram
#(	parameter integer DWIDTH = 32,
 	parameter integer AWIDTH = 4
)

(
	input clock, reset, wr_en, rd_en,
	input [DWIDTH-1:0] data_in,
	input [AWIDTH-1:0] wr_addr,
	output reg [DWIDTH-1:0] data_out,
	input [AWIDTH-1:0] rd_addr
);

	reg [DWIDTH-1:0] mem [0:2**AWIDTH-1];
	integer i;

	always @(*)
	begin
		if (reset)
		begin
			for (i = 0; i < 16; i = i + 1)
			begin
				mem[i] <= {DWIDTH{1'b0}};
			end
			data_out <= {DWIDTH{1'b0}};
		end
		else
		begin
			if (wr_en)
			begin
				mem[wr_addr] <= data_in;
			end
			if (rd_en)
			begin
				data_out <= mem[rd_addr];
			end
		end
	end
endmodule
