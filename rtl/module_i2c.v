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


`timescale 1ns/1ps //timescale 

module module_i2c#(
			//THIS IS USED ONLY LIKE PARAMETER TO BEM CONFIGURABLE
			parameter integer DWIDTH = 32,
			parameter integer AWIDTH = 14
		)
		(
		//I2C INTERFACE WITH ANOTHER BLOCKS
		 input PCLK,
		 input PRESETn,
		 
		//INTERFACE WITH FIFO TRANSMISSION
		 input fifo_tx_f_full,
		 input fifo_tx_f_empty,
		 input [DWIDTH-1:0] fifo_tx_data_out,

		//INTERFACE WITH FIFO RECEIVER
		 input fifo_rx_f_full,
		 input fifo_rx_f_empty,
		 output reg fifo_rx_wr_en,
		 output reg [DWIDTH-1:0] fifo_rx_data_in, 

		//INTERFACE WITH REGISTER CONFIGURATION
		 input [AWIDTH-1:0] DATA_CONFIG_REG,
		
		//INTERFACE TO APB AND READ FOR FIFO TX
		 output reg fifo_tx_rd_en,
		 output TX_EMPTY,
		 output RX_EMPTY,
		 output ERROR,

		//I2C BI DIRETIONAL PORTS
		inout SDA,
		inout SCL
		 

		 );

//THIS IS USED TO GENERATE INTERRUPTIONS
assign TX_EMPTY = (fifo_tx_f_empty == 1'b1)? 1'b1:1'b0;
assign RX_EMPTY = (fifo_rx_f_empty == 1'b1)? 1'b1:1'b0;

	//THIS COUNT IS USED TO CONTROL DATA ACCROSS FSM	
	reg [1:0] count_tx;
	//CONTROL CLOCK AND COUNTER
	reg [11:0] count_send_data;
	reg BR_CLK_O;
	reg SDA_OUT;

	//RESPONSE USED TO HOLD SIGNAL TO ACK OR NACK
	reg RESPONSE;

// TX PARAMETERS USED TO STATE MACHINE

localparam [5:0] TX_IDLE = 6'd0, //IDLE

	   TX_START = 6'd1,//START BIT

	   TX_CONTROLIN_1 = 6'd2, //START BYTE
	   TX_CONTROLIN_2 = 6'd3,
	   TX_CONTROLIN_3 = 6'd4,
           TX_CONTROLIN_4 = 6'd5,
	   TX_CONTROLIN_5 = 6'd6,
	   TX_CONTROLIN_6 = 6'd7,
           TX_CONTROLIN_7 = 6'd8,
           TX_CONTROLIN_8 = 6'd9, //END FIRST BYTE

	   TX_RESPONSE_CIN =6'd10, //RESPONSE

	   TX_ADRESS_1 = 6'd11,//START BYTE
	   TX_ADRESS_2 = 6'd12,
	   TX_ADRESS_3 = 6'd13,
           TX_ADRESS_4 = 6'd14,
	   TX_ADRESS_5 = 6'd15,
	   TX_ADRESS_6 = 6'd16,
           TX_ADRESS_7 = 6'd17,
           TX_ADRESS_8 = 6'd18,//END FIRST BYTE

	   TX_RESPONSE_ADRESS =6'd19, //RESPONSE

	   TX_DATA0_1 = 6'd20,//START BYTE
	   TX_DATA0_2 = 6'd21,
	   TX_DATA0_3 = 6'd22,
           TX_DATA0_4 = 6'd23,
	   TX_DATA0_5 = 6'd24,
	   TX_DATA0_6 = 6'd25,
           TX_DATA0_7 = 6'd26,
           TX_DATA0_8 = 6'd27,//END FIRST BYTE

	   TX_RESPONSE_DATA0_1 = 6'd28,  //RESPONSE
	   
	   TX_DATA1_1 = 6'd29,//START BYTE
	   TX_DATA1_2 = 6'd30,
	   TX_DATA1_3 = 6'd31,
           TX_DATA1_4 = 6'd32,
	   TX_DATA1_5 = 6'd33,
	   TX_DATA1_6 = 6'd34,
           TX_DATA1_7 = 6'd35,
           TX_DATA1_8 = 6'd36,//END FIRST BYTE

	   TX_RESPONSE_DATA1_1 = 6'd37,//RESPONSE

	   TX_DELAY_BYTES = 6'd38,//USED ONLY IN ACK TO DELAY BETWEEN
	   TX_NACK = 6'd39,//USED ONLY IN ACK TO DELAY BETWEEN BYTES
	   TX_STOP = 6'd40;//USED TO SEND STOP BIT

	//STATE CONTROL 
	reg [5:0] state_tx;
	reg [5:0] next_state_tx;

//ASSIGN REGISTERS TO BIDIRETIONAL PORTS
assign SDA = (DATA_CONFIG_REG[0] == 1'b1 & DATA_CONFIG_REG[1] == 1'b0)?SDA_OUT:1'b0;
assign SCL = (DATA_CONFIG_REG[0] == 1'b1 & DATA_CONFIG_REG[1] == 1'b0)?BR_CLK_O:1'b0;

//STANDARD ERROR
assign ERROR = (DATA_CONFIG_REG[0] == 1'b1 & DATA_CONFIG_REG[1] == 1'b1)?1'b1:1'b0;

//COMBINATIONAL BLOCK TO TX
always@(*)
begin

	//THE FUN START HERE :-)
	//COMBINATIONAL UPDATE STATE BE CAREFUL WITH WHAT YOU MAKE HERE
	next_state_tx = state_tx;

	case(state_tx)//STATE_TX IS MORE SECURE CHANGE ONLY IF YOU KNOW WHAT ARE YOU DOING 
	TX_IDLE:
	begin
		//OBEYING SPEC
		if(DATA_CONFIG_REG[0] == 1'b0 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b0)
		begin
			next_state_tx = TX_IDLE;
		end
		else if(DATA_CONFIG_REG[0] == 1'b1 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b1)
		begin
			next_state_tx = TX_IDLE;
		end
		else if(DATA_CONFIG_REG[0] == 1'b1 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b0)
		begin
			next_state_tx = TX_START;
		end


	end
	TX_START://THIS IS USED TOO ALL STATE MACHINES THE COUNTER_SEND_DATA
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_START;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_1;
		end
		
	end
	TX_CONTROLIN_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_1;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_2;
		end

	end
	TX_CONTROLIN_2:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx =TX_CONTROLIN_2;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_3;
		end

	end
	TX_CONTROLIN_3:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_3;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_4;
		end		
	end
	TX_CONTROLIN_4:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_4;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_5;
		end		
	end
	TX_CONTROLIN_5:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_5;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_6;
		end		
	end
	TX_CONTROLIN_6:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_6;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_7;
		end		
	end
	TX_CONTROLIN_7:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_7;
		end
		else
		begin
			next_state_tx = TX_CONTROLIN_8;
		end		
	end
	TX_CONTROLIN_8:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_CONTROLIN_8;
		end
		else 
		begin
			next_state_tx = TX_RESPONSE_CIN;
		end		
	end
	TX_RESPONSE_CIN:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_RESPONSE_CIN;
		end
		else if(RESPONSE == 1'b0)//ACK
		begin 
			next_state_tx = TX_DELAY_BYTES;
		end
		else if(RESPONSE == 1'b1)//NACK
		begin
			next_state_tx = TX_NACK;
		end	
		
	end

	//NOW SENDING ADDRESS
	TX_ADRESS_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_1;
		end
		else
		begin
			next_state_tx = TX_ADRESS_2;
		end	
	end
	TX_ADRESS_2:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_2;
		end
		else
		begin
			next_state_tx = TX_ADRESS_3;
		end	
	end
	TX_ADRESS_3:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_3;
		end
		else
		begin
			next_state_tx = TX_ADRESS_4;
		end	
	end
	TX_ADRESS_4:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_4;
		end
		else
		begin
			next_state_tx = TX_ADRESS_5;
		end	
	end
	TX_ADRESS_5:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_5;
		end
		else
		begin
			next_state_tx = TX_ADRESS_6;
		end	
	end
	TX_ADRESS_6:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_6;
		end
		else
		begin
			next_state_tx = TX_ADRESS_7;
		end	
	end
	TX_ADRESS_7:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_7;
		end
		else
		begin
			next_state_tx = TX_ADRESS_8;
		end	
	end
	TX_ADRESS_8:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_ADRESS_8;
		end
		else
		begin
			next_state_tx = TX_RESPONSE_ADRESS;
		end	
	end
	TX_RESPONSE_ADRESS:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_RESPONSE_ADRESS;
		end
		else if(RESPONSE == 1'b0)//ACK
		begin 
			next_state_tx = TX_DELAY_BYTES;
		end
		else if(RESPONSE == 1'b1)//NACK --> RESTART CONDITION AND BACK TO START BYTE AGAIN
		begin
			next_state_tx = TX_NACK;
		end	
	end
	
	//data in
	TX_DATA0_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_1;
		end
		else
		begin
			next_state_tx = TX_DATA0_2;
		end
	end
	TX_DATA0_2:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_2;
		end
		else
		begin
			next_state_tx = TX_DATA0_3;
		end
	end
	TX_DATA0_3:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_3;
		end
		else
		begin
			next_state_tx = TX_DATA0_4;
		end
	end
	TX_DATA0_4:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_4;
		end
		else
		begin
			next_state_tx = TX_DATA0_5;
		end
	end
	TX_DATA0_5:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_5;
		end
		else
		begin
			next_state_tx = TX_DATA0_6;
		end
	end
	TX_DATA0_6:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_6;
		end
		else
		begin
			next_state_tx = TX_DATA0_7;
		end
	end
	TX_DATA0_7:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_7;
		end
		else
		begin
			next_state_tx = TX_DATA0_8;
		end
	end
	TX_DATA0_8:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA0_8;
		end
		else
		begin
			next_state_tx = TX_RESPONSE_DATA0_1;
		end
	end
	TX_RESPONSE_DATA0_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_RESPONSE_DATA0_1;
		end
		else if(RESPONSE == 1'b0)//ACK
		begin 
			next_state_tx = TX_DELAY_BYTES;
		end
		else if(RESPONSE == 1'b1)//NACK
		begin
			next_state_tx = TX_NACK;
		end	
	end

	//second byte
	TX_DATA1_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_1;
		end
		else
		begin
			next_state_tx = TX_DATA1_2;
		end
	end
	TX_DATA1_2:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_2;
		end
		else
		begin
			next_state_tx = TX_DATA1_3;
		end
	end
	TX_DATA1_3:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_3;
		end
		else
		begin
			next_state_tx = TX_DATA1_4;
		end
	end
	TX_DATA1_4:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_4;
		end
		else
		begin
			next_state_tx = TX_DATA1_5;
		end
	end
	TX_DATA1_5:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_5;
		end
		else
		begin
			next_state_tx = TX_DATA1_6;
		end
	end
	TX_DATA1_6:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_6;
		end
		else
		begin
			next_state_tx = TX_DATA1_7;
		end
	end
	TX_DATA1_7:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_7;
		end
		else
		begin
			next_state_tx = TX_DATA1_8;
		end
	end
	TX_DATA1_8:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DATA1_8;
		end
		else
		begin
			next_state_tx = TX_RESPONSE_DATA1_1;
		end
	end
	TX_RESPONSE_DATA1_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_RESPONSE_DATA1_1;
		end
		else if(RESPONSE == 1'b0)//ACK
		begin 
			next_state_tx = TX_DELAY_BYTES;
		end
		else if(RESPONSE == 1'b1)//NACK
		begin
			next_state_tx = TX_NACK;
		end	
	end
	TX_DELAY_BYTES://THIS FORM WORKS 
	begin

		
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_DELAY_BYTES;
		end
		else
		begin

			if(count_tx == 2'd0)
			begin
				next_state_tx = TX_ADRESS_1;
			end
			else if(count_tx == 2'd1)
			begin
				next_state_tx = TX_DATA0_1;
			end
			else if(count_tx == 2'd2)
			begin
				next_state_tx = TX_DATA1_1;
			end
			else if(count_tx == 2'd3)
			begin
				next_state_tx = TX_STOP;
			end
			
		end

	end
	TX_NACK://NOT TESTED YET !!!!
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2]*2'd2)
		begin
			next_state_tx = TX_NACK;
		end
		else
		begin
			if(count_tx == 2'd0)
			begin
				next_state_tx = TX_CONTROLIN_1;
			end
			else if(count_tx == 2'd1)
			begin
				next_state_tx = TX_ADRESS_1;
			end
			else if(count_tx == 2'd2)
			begin
				next_state_tx = TX_DATA0_1;
			end
			else if(count_tx == 2'd3)
			begin
				next_state_tx = TX_DATA1_1;
			end
		end
	end
	TX_STOP://THIS WORK
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = TX_STOP;
		end
		else
		begin
			next_state_tx = TX_IDLE;
		end
	end
	default:
	begin
		next_state_tx = TX_IDLE;
	end
	endcase


end
//SEQUENTIAL TX
always@(posedge PCLK)
begin

	//RESET SYNC
	if(!PRESETn)
	begin
		//SIGNALS MUST BE RESETED
		count_send_data <= 12'd0;
		state_tx <= TX_IDLE;	
		SDA_OUT<= 1'b1;
		fifo_tx_rd_en <= 1'b0;
		count_tx <= 2'd0;
		BR_CLK_O <= 1'b1;
		RESPONSE<= 1'b0;	
	end
	else
	begin
		
		// SEQUENTIAL FUN START
		state_tx <= next_state_tx;

		case(state_tx)
		TX_IDLE:
		begin

			fifo_tx_rd_en <= 1'b0;
			
 
			if(DATA_CONFIG_REG[0] == 1'b0 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b0)
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b1;
				BR_CLK_O <= 1'b1;
			end
			else if(DATA_CONFIG_REG[0] == 1'b1 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b0)
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=1'b0;			
			end
			else if(DATA_CONFIG_REG[0] == 1'b1 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b1)
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b1;
				BR_CLK_O <= 1'b1;
			end			

		end
		TX_START:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				BR_CLK_O <= 1'b0;
			end
			else
			begin
				count_send_data <= 12'd0;					
			end	

			if(count_send_data == DATA_CONFIG_REG[13:2]- 12'd1)
			begin
				SDA_OUT<=fifo_tx_data_out[0:0];
				count_tx <= 2'd0;
			end

		end
		TX_CONTROLIN_1:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[0:0];	

								
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[1:1];
			end

				
		end
		
		TX_CONTROLIN_2:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[1:1];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[2:2];
			end
				
		end

		TX_CONTROLIN_3:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[2:2];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[3:3];
			end	


				
		end
		TX_CONTROLIN_4:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[3:3];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[4:4];
			end
				
		end

		TX_CONTROLIN_5:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[4:4];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[5:5];
			end	

		end


		TX_CONTROLIN_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[5:5];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[6:6];
			end	

				
		end

		TX_CONTROLIN_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[6:6];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[7:7];
			end	

				
		end
		TX_CONTROLIN_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[7:7];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b0;
			end

				
		end
		TX_RESPONSE_CIN:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
			end	


		end
		TX_ADRESS_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[8:8];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[9:9];
			end	
				
		end		
		TX_ADRESS_2:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[9:9];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[10:10];
			end	

		end
		TX_ADRESS_3:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[10:10];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[11:11];
			end	

		end
		TX_ADRESS_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[11:11];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[12:12];
			end	
		end
		TX_ADRESS_5:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[12:12];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[13:13];
			end	

				
		end
		TX_ADRESS_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[13:13];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;		
				SDA_OUT<=fifo_tx_data_out[14:14];
			end	
				
		end
		TX_ADRESS_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[14:14];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[15:15];
			end	

				
		end
		TX_ADRESS_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[15:15];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=1'b0;
			end	
				
		end
		TX_RESPONSE_ADRESS:
		begin
			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
			end

		end
		TX_DATA0_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[16:16];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;				
				SDA_OUT<=fifo_tx_data_out[17:17];
			end	

				
		end
		TX_DATA0_2:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[17:17];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[18:18];
			end	

				
		end		
		TX_DATA0_3:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[18:18];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[19:19];
			end	
				
		end
		TX_DATA0_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[19:19];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[20:20];
			end	
				
		end
		TX_DATA0_5:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[20:20];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[21:21];
			end

		end
		TX_DATA0_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[21:21];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[22:22];
			end
				
		end
		TX_DATA0_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[22:22];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[23:23];
			end	
				
		end
		TX_DATA0_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[23:23];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=1'b0;
			end	
				
		end
		TX_RESPONSE_DATA0_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
			end

		end
		TX_DATA1_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[24:24];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[25:25];

			end

				
		end
		TX_DATA1_2:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[25:25];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[26:26];
			end	

		end
		TX_DATA1_3:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[26:26];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[27:27];
			end	
				
		end
		TX_DATA1_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[27:27];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[28:28];
			end	
				
		end
		TX_DATA1_5:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[28:28];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[29:29];
			end	
				
		end
		TX_DATA1_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[29:29];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[30:30];
			end	
				
		end
		TX_DATA1_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[30:30];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[31:31];
			end	

				
		end
		TX_DATA1_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[31:31];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=1'b0;
			end	
				
		end
		TX_RESPONSE_DATA1_1:
		begin
			//fifo_tx_rd_en <= 1'b1;

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				fifo_tx_rd_en <= 1'b1;
			end	

		end
		TX_DELAY_BYTES:
		begin
			
			fifo_tx_rd_en <= 1'b0;
		
			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				
				count_send_data <= count_send_data + 12'd1;	
				BR_CLK_O <= 1'b0;
				SDA_OUT<=1'b0;		
			end
			else
			begin


				if(count_tx == 2'd0)
				begin
					count_tx <= count_tx + 2'd1;
					SDA_OUT<=fifo_tx_data_out[8:8];
				end
				else if(count_tx == 2'd1)
				begin
					count_tx <= count_tx + 2'd1;
					SDA_OUT<=fifo_tx_data_out[16:16];
				end
				else if(count_tx == 2'd2)
				begin
					count_tx <= count_tx + 2'd1;
					SDA_OUT<=fifo_tx_data_out[24:24];
				end
				else if(count_tx == 2'd3)
				begin
					count_tx <= 2'd0;
				end

				count_send_data <= 12'd0;
			
			end

		end
		//THIS BLOCK MUST BE CHECKED WITH CARE
		TX_NACK:// MORE A RESTART 
		begin
			fifo_tx_rd_en <= 1'b0;
		
			if(count_send_data < DATA_CONFIG_REG[13:2]*2'd2)
			begin		
				count_send_data <= count_send_data + 12'd1;
	
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd2)
				begin
					SDA_OUT<=1'b0;
				end
				else if(count_send_data > DATA_CONFIG_REG[13:2]/12'd2-12'd1 && count_send_data < DATA_CONFIG_REG[13:2])
				begin
					SDA_OUT<=1'b1;
				end
				else if(count_send_data  == DATA_CONFIG_REG[13:2]*2'd2)
				begin
					SDA_OUT<=1'b0;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd2)
				begin
					BR_CLK_O <= 1'b1;
				end
				else if(count_send_data > DATA_CONFIG_REG[13:2]/12'd2-12'd1 && count_send_data < DATA_CONFIG_REG[13:2])
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data < DATA_CONFIG_REG[13:2]*2'd2)
				begin
					BR_CLK_O <= 1'b1;
				end
		
			end
			else
			begin
				count_send_data <= 12'd0;

				if(count_tx == 2'd0)
				begin
					count_tx <= 2'd0;
					SDA_OUT<=fifo_tx_data_out[0:0];
				end
				else if(count_tx == 2'd1)
				begin
					count_tx <= 2'd1;
					SDA_OUT<=fifo_tx_data_out[8:8];
				end
				else if(count_tx == 2'd2)
				begin
					count_tx <= 2'd2;
					SDA_OUT<=fifo_tx_data_out[16:16];
				end
				else if(count_tx == 2'd3)
				begin
					count_tx <= 2'd3;
					SDA_OUT<=fifo_tx_data_out[24:24];
				end

			
			end
		end
		TX_STOP:
		begin

			BR_CLK_O <= 1'b1;

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd2-12'd2)
				begin
					SDA_OUT<=1'b0;
				end
				else if(count_send_data > DATA_CONFIG_REG[13:2]/12'd2-12'd1 && count_send_data < DATA_CONFIG_REG[13:2])
				begin
					SDA_OUT<=1'b1;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
			end
		end
		default:
		begin
			fifo_tx_rd_en <= 1'b0;
			count_send_data <= 12'd4095;
		end
		endcase
		
	end


end 


// RX PARAMETERS USED TO STATE MACHINE

localparam [5:0] RX_IDLE = 6'd0, //IDLE

	   RX_START = 6'd1,//START BIT

	   RX_CONTROLIN_1 = 6'd2, //START BYTE
	   RX_CONTROLIN_2 = 6'd3,
	   RX_CONTROLIN_3 = 6'd4,
           RX_CONTROLIN_4 = 6'd5,
	   RX_CONTROLIN_5 = 6'd6,
	   RX_CONTROLIN_6 = 6'd7,
           RX_CONTROLIN_7 = 6'd8,
           RX_CONTROLIN_8 = 6'd9, //END FIRST BYTE

	   RX_RESPONSE_CIN =6'd10, //RESPONSE

	   RX_ADRESS_1 = 6'd11,//START BYTE
	   RX_ADRESS_2 = 6'd12,
	   RX_ADRESS_3 = 6'd13,
           RX_ADRESS_4 = 6'd14,
	   RX_ADRESS_5 = 6'd15,
	   RX_ADRESS_6 = 6'd16,
           RX_ADRESS_7 = 6'd17,
           RX_ADRESS_8 = 6'd18,//END FIRST BYTE

	   RX_RESPONSE_ADRESS =6'd19, //RESPONSE

	   RX_DATA0_1 = 6'd20,//START BYTE
	   RX_DATA0_2 = 6'd21,
	   RX_DATA0_3 = 6'd22,
           RX_DATA0_4 = 6'd23,
	   RX_DATA0_5 = 6'd24,
	   RX_DATA0_6 = 6'd25,
           RX_DATA0_7 = 6'd26,
           RX_DATA0_8 = 6'd27,//END FIRST BYTE

	   RX_RESPONSE_DATA0_1 = 6'd28,  //RESPONSE
	   
	   RX_DATA1_1 = 6'd29,//START BYTE
	   RX_DATA1_2 = 6'd30,
	   RX_DATA1_3 = 6'd31,
           RX_DATA1_4 = 6'd32,
	   RX_DATA1_5 = 6'd33,
	   RX_DATA1_6 = 6'd34,
           RX_DATA1_7 = 6'd35,
           RX_DATA1_8 = 6'd36,//END FIRST BYTE

	   RX_RESPONSE_DATA1_1 = 6'd37,//RESPONSE

	   RX_DELAY_BYTES = 6'd38,//USED ONLY IN ACK TO DELAY BETWEEN
	   RX_NACK = 6'd39,//USED ONLY IN ACK TO DELAY BETWEEN BYTES
	   RX_STOP = 6'd40;//USED TO SEND STOP BIT

	//STATE CONTROL 
	reg [5:0] state_rx;
	reg [5:0] next_state_rx;

	reg [11:0] count_receive_data;

	reg [1:0] count_rx;

//COMBINATIONAL BLOCK RX

always@(*)
begin


	next_state_rx = state_rx;

	case(state_rx)//STATE_RX IS MORE SECURE CHANGE ONLY IF YOU KNOW WHAT ARE YOU DOING 
	RX_IDLE:
	begin
		//OBEYING SPEC
		if(DATA_CONFIG_REG[1] == 1'b0 && DATA_CONFIG_REG[0] == 1'b0)
		begin
			next_state_rx = RX_IDLE;
		end
		else if(DATA_CONFIG_REG[1] == 1'b1 && DATA_CONFIG_REG[0] == 1'b1)
		begin
			next_state_rx = RX_IDLE;
		end
		else if(DATA_CONFIG_REG[1] == 1'b1 && DATA_CONFIG_REG[0] == 1'b0 && SDA == 1'b0 && SCL == 1'b1)
		begin
			next_state_rx = RX_START;
		end
	end
	RX_START:
	begin

		if(SDA == 1'b0 && SCL == 1'b1)
		begin		
			if(count_receive_data != DATA_CONFIG_REG[13:2])
			begin
				next_state_rx = RX_START;
			end
			else
			begin
				next_state_rx = RX_CONTROLIN_1;
			end
		end
		else
		begin
			next_state_rx = RX_IDLE;
		end
	end
	RX_CONTROLIN_1:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_1;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_2;
		end
	end
	RX_CONTROLIN_2:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_2;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_3;
		end
	end
	RX_CONTROLIN_3:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_3;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_4;
		end
	end
	RX_CONTROLIN_4:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_4;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_5;
		end
	end
	RX_CONTROLIN_5:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_5;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_6;
		end
	end
	RX_CONTROLIN_6:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_6;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_7;
		end
	end
	RX_CONTROLIN_7:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_7;
		end
		else
		begin
			next_state_rx = RX_CONTROLIN_8;
		end
	end
	RX_CONTROLIN_8:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_8;
		end
		else
		begin
			next_state_rx = RX_RESPONSE_CIN;
		end
	end
	RX_RESPONSE_CIN:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_CONTROLIN_8;
		end
		else
		begin
			next_state_rx = RX_RESPONSE_CIN;
		end
	end

	RX_ADRESS_1:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_1;
		end
		else
		begin
			next_state_rx = RX_ADRESS_2;
		end
	end
	RX_ADRESS_2:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_2;
		end
		else
		begin
			next_state_rx = RX_ADRESS_3;
		end
	end
	RX_ADRESS_3:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_3;
		end
		else
		begin
			next_state_rx = RX_ADRESS_4;
		end
	end
	RX_ADRESS_4:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_4;
		end
		else
		begin
			next_state_rx = RX_ADRESS_5;
		end
	end
	RX_ADRESS_5:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_5;
		end
		else
		begin
			next_state_rx = RX_ADRESS_6;
		end
	end
	RX_ADRESS_6:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_6;
		end
		else
		begin
			next_state_rx = RX_ADRESS_7;
		end
	end
	RX_ADRESS_7:
	begin

		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_7;
		end
		else
		begin
			next_state_rx = RX_ADRESS_8;
		end

	end
	RX_ADRESS_8:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_ADRESS_8;
		end
		else
		begin
			next_state_rx = RX_RESPONSE_ADRESS;
		end
	end
	RX_RESPONSE_ADRESS:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_RESPONSE_ADRESS;
		end
		else
		begin
			next_state_rx = RX_DATA0_1;
		end
	end

	RX_DATA0_1:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_1;
		end
		else
		begin
			next_state_rx = RX_DATA0_2;
		end
	end
	RX_DATA0_2:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_2;
		end
		else
		begin
			next_state_rx = RX_DATA0_3;
		end
	end
	RX_DATA0_3:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_3;
		end
		else
		begin
			next_state_rx = RX_DATA0_4;
		end
	end
	RX_DATA0_4:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_4;
		end
		else
		begin
			next_state_rx = RX_DATA0_5;
		end
	end
	RX_DATA0_5:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_5;
		end
		else
		begin
			next_state_rx = RX_DATA0_6;
		end
	end
	RX_DATA0_6:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_6;
		end
		else
		begin
			next_state_rx = RX_DATA0_7;
		end
	end
	RX_DATA0_7:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_7;
		end
		else
		begin
			next_state_rx = RX_DATA0_8;
		end
	end
	RX_DATA0_8:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA0_8;
		end
		else
		begin
			next_state_rx = RX_RESPONSE_DATA0_1;
		end
	end
	RX_RESPONSE_DATA0_1:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_RESPONSE_DATA0_1;
		end
		else
		begin
			next_state_rx = RX_DATA1_1;
		end
	end
	RX_DATA1_1:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_1;
		end
		else
		begin
			next_state_rx = RX_DATA1_2;
		end
	end
	RX_DATA1_2:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_1;
		end
		else
		begin
			next_state_rx = RX_DATA1_3;
		end
	end
	RX_DATA1_3:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_3;
		end
		else
		begin
			next_state_rx = RX_DATA1_4;
		end
	end
	RX_DATA1_4:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_4;
		end
		else
		begin
			next_state_rx = RX_DATA1_5;
		end
	end
	RX_DATA1_5:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_5;
		end
		else
		begin
			next_state_rx = RX_DATA1_6;
		end
	end
	RX_DATA1_6:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_6;
		end
		else
		begin
			next_state_rx = RX_DATA1_7;
		end
	end
	RX_DATA1_7:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_7;
		end
		else
		begin
			next_state_rx = RX_DATA1_8;
		end
	end
	RX_DATA1_8:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DATA1_8;
		end
		else
		begin
			next_state_rx = RX_RESPONSE_DATA1_1;
		end
	end
	RX_RESPONSE_DATA1_1:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_RESPONSE_DATA1_1;
		end
		else
		begin
			next_state_rx = RX_DELAY_BYTES;
		end
	end
	RX_DELAY_BYTES:
	begin
		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_DELAY_BYTES;
		end
		else
		begin

			if(count_rx == 2'd0)
			begin
				next_state_rx = RX_ADRESS_1;
			end
			else if(count_rx == 2'd1)
			begin
				next_state_rx = RX_DATA0_1;
			end
			else if(count_rx == 2'd2)
			begin
				next_state_rx = RX_DATA1_1;
			end
			else if(count_rx == 2'd3)
			begin
				next_state_rx = RX_STOP;
			end
			
		end
	end
	RX_NACK:
	begin

			if(count_receive_data != DATA_CONFIG_REG[13:2]*2'd2)
			begin
				next_state_rx = RX_NACK;
			end
			else
			begin
				if(count_rx == 2'd0)
				begin
					next_state_rx = RX_CONTROLIN_1;
				end
				else if(count_rx == 2'd1)
				begin
					next_state_rx = RX_ADRESS_1;
				end
				else if(count_rx == 2'd2)
				begin
					next_state_rx = RX_DATA0_1;
				end
				else if(count_rx == 2'd3)
				begin
					next_state_rx = RX_DATA1_1;
				end
			end


	end
	RX_STOP:
	begin

		if(count_receive_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_rx = RX_STOP;
		end
		else
		begin
			next_state_rx = RX_IDLE;
		end

	end	
	default:
	begin
			next_state_rx = RX_IDLE;
	end
	endcase
end


//SEQUENTIAL BLOCK RX

always@(posedge PCLK)
begin

	if(!PRESETn)
	begin
		//SIGNALS MUST BE RESETED
		count_receive_data <= 12'd0;
		state_rx <= RX_IDLE;	
		fifo_rx_wr_en <= 1'b0;
		count_rx <= 2'd0;	
	end
	else
	begin

		state_rx <= next_state_rx;

		case(state_rx)//STATE_RX IS MORE SECURE CHANGE ONLY IF YOU KNOW WHAT ARE YOU DOING 
		RX_IDLE:
		begin
			if(SDA == 1'b0 && SCL == 1'b1)
			begin
				count_receive_data <= count_receive_data +12'd1;
			end
			else
			begin
				count_receive_data <= 12'd0;
			end
		end
		RX_START:
		begin
			if(SDA == 1'b0 && SCL == 1'b0 && count_receive_data < DATA_CONFIG_REG[13:2] )
			begin
				count_receive_data <= count_receive_data +12'd1;
			end
			else
			begin
				count_receive_data <= 12'd0;
			end
		end
		RX_CONTROLIN_1:
		begin
	
		end
		RX_CONTROLIN_2:
		begin

		end
		RX_CONTROLIN_3:
		begin

		end
		RX_CONTROLIN_4:
		begin

		end
		RX_CONTROLIN_5:
		begin

		end
		RX_CONTROLIN_6:
		begin

		end
		RX_CONTROLIN_7:
		begin

		end
		RX_CONTROLIN_8:
		begin

		end
		RX_RESPONSE_CIN:
		begin

		end
		RX_ADRESS_1:
		begin
		end
		RX_ADRESS_2:
		begin
		end
		RX_ADRESS_3:
		begin
		end
		RX_ADRESS_4:
		begin
		end
		RX_ADRESS_5:
		begin
		end
		RX_ADRESS_6:
		begin
		end
		RX_ADRESS_7:
		begin
		end
		RX_ADRESS_8:
		begin
		end
		RX_RESPONSE_ADRESS:
		begin

		end
		RX_DATA0_1:
		begin

		end
		RX_DATA0_2:
		begin

		end
		RX_DATA0_3:
		begin

		end
		RX_DATA0_4:
		begin

		end
		RX_DATA0_5:
		begin

		end
		RX_DATA0_6:
		begin

		end
		RX_DATA0_7:
		begin

		end
		RX_DATA0_8:
		begin

		end
		RX_RESPONSE_DATA0_1:
		begin
		end

		RX_DATA1_1:
		begin

		end
		RX_DATA1_2:
		begin

		end
		RX_DATA1_3:
		begin

		end
		RX_DATA1_4:
		begin

		end
		RX_DATA1_5:
		begin

		end
		RX_DATA1_6:
		begin

		end
		RX_DATA1_7:
		begin

		end
		RX_DATA1_8:
		begin

		end
		RX_RESPONSE_DATA1_1:
		begin
		end
		RX_DELAY_BYTES:
		begin

		end
		RX_NACK:
		begin


		end
		RX_STOP:
		begin


		end	
		default:
		begin
			count_receive_data <= 12'd4095;
			fifo_rx_wr_en <= 1'b0;
			count_rx <= 2'd3;
		end
		endcase
	end
end

endmodule
