/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tqv_jesari_CRC (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);
	// changing the bus interface to LaRVa's...

	// Chip select
	wire cs = (address[1:0]==0) & ((data_write_n!=2'b11) | (data_read_n!=2'b11));

	// byte write lanes
	wire [3:0]bsel;
	assign bsel[0] = (data_write_n!=2'b11);
	assign bsel[1] = (data_write_n==2'b01) | (data_write_n==2'b10);
	assign bsel[2] = (data_write_n==2'b10);
	assign bsel[3] = bsel[2];

	// peripheral instance
	wire irqrx, irqrxerr, irqtx, can_tx, can_rx;
	CRC CRC0 (
		.clk(clk), .reset(~rst_n),
		.cs(cs), 
		.rs(address[3:2]),
		.wrl(bsel),
		.d(data_in),
		.q(data_out)
	);
	
	// fixed outputs
	assign data_ready = 1'b1;
    assign uo_out = 8'hZZ; 
    assign user_interrupt = 1'b0;
	
    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{ui_in[7:0], address[5:4], rst_n, 1'b0};

endmodule

///////////////////////////////////////
///////////////////////////////////////
// CRC accelerator
// J. Arias (2022)
// original version for laRVa cores...
///////////////////////////////////////
///////////////////////////////////////

module CRC (
	input clk,
	input reset,	// Async, just to avoid Xs during simulation
	input cs,		// Chip Select
	input [1:0]rs,	// register select (address)
	input [3:0]wrl,	// Write Lanes
	input [31:0]d,	// input data bus
	output [31:0]q  // output data bus
);

///////////////////////////////////////
// registers

reg [31:0]sh;	// Data shift register
reg [31:0]crc;	// CRC register
reg [31:0]poly;	// CRC polynomial
reg [ 5:0]cnt;	// Bit counter

///////////////////////////////////////
// WRITE registers
//  RS    REG
//---------------
//  00    CRC  (32 bits, MSB justified)
//  01    POLY (32 bits, MSB justified)
//  10    DATA (32, 16, or 8 bits)
//  11    REFL (bits reflected, 32, 16, or 8 bits)

wire wr=cs & (wrl!=0);	// Write something signal

// Data shift register (Little-endian byte order for non-reflected values)
// Don't care values in LSBs for 16-bit and 8-bit writes
// Reverse bit order for "reflected" data
wire datawr=    wr & (rs==2'b10);
wire reflectwr= wr & (rs==2'b11);
always @(posedge clk)
	 sh<=(datawr|reflectwr) ? (reflectwr ? 
	 	{ d[ 0],d[ 1],d[ 2],d[ 3],d[ 4],d[ 5],d[ 6],d[ 7],
	 	  d[ 8],d[ 9],d[10],d[11],d[12],d[13],d[14],d[15],
	 	  d[16],d[17],d[18],d[19],d[20],d[21],d[22],d[23],
	 	  d[24],d[25],d[26],d[27],d[28],d[29],d[30],d[31] }:
	 	{d[7:0],d[15:8],d[23:16],d[31:24]} ):
	  {sh[30:0],1'bx};
// Bit downcounter. Starts with 31, 15 or 7, depending on write lanes.
always @(posedge clk or posedge reset)
	if (reset) cnt<=0; else
		if (datawr|reflectwr) cnt<={1'b0,wrl[3],wrl[1],wrl[0],wrl[0],wrl[0]};
		else if (~tc) cnt<=cnt-1;
wire tc=cnt[5]; // Terminal Count: count until -1 (MSB==1)

// Polynomial register (MSB justified)
always @(posedge clk)
	if (wr&(rs==2'b01)) poly<=d;

// CRC
always @(posedge clk)
	if (wr&(rs==2'b00)) crc<=d;	// Initial value (MSB justified)
	else if (~tc) crc<= {crc[30:0],1'b0}^((crc[31]^sh[31])? poly : 0); 

///////////////////////////////////////
// READ registers
//  RS    REG
//---------------
//  00    CRC  (MSB justified)
//  01    STAT (bit 0: ready if 1, busy if 0)
//  1x    CRC  (bits reflected, LSB justified)

assign q= rs[1]? 
		{ crc[ 0],crc[ 1],crc[ 2],crc[ 3],crc[ 4],crc[ 5],crc[ 6],crc[ 7],
		  crc[ 8],crc[ 9],crc[10],crc[11],crc[12],crc[13],crc[14],crc[15],
		  crc[16],crc[17],crc[18],crc[19],crc[20],crc[21],crc[22],crc[23],
		  crc[24],crc[25],crc[26],crc[27],crc[28],crc[29],crc[30],crc[31]} :
		(rs[0] ? {31'b0,tc} : crc); 

endmodule



