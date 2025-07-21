<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## What it does

This peripheral is a hardware accelerator for the computation of CRCs, not an I/O device. It computes any kind
 of CRC one bit at a time, so, it takes 8 clock cycles for a byte. Its features also include:

- CRC polynomials up to 32 bits

- Normal or “reflected” CRCs

- Any initial value allowed

And, for the programmer's model it has the following registers:

## Register map

| Address | Name     | Access | size | Description                                          |
|---------|----------|--------|------|------------------------------------------------------|
| 0x00    | CRC      |  R/W   | word | Current CRC value, right aligned                     |
|---------|----------|--------|------|------------------------------------------------------|
| 0x04    | STAT     |   R    | any  | Bit #0: CRC ready if one                             |
|         | POLY     |   W    | word | CRC polynomial, right aligned, LSBs padded with 0s   |
|---------|----------|--------|------|------------------------------------------------------|
| 0x08    | CRCREFL  |   R    | word | Current CRC "reflected" (LSBs and MSBs interchanged) |
|         | DATA     |   W    | word | Adds 4 bytes to CRC (little endian)                  |
|         |          |   W    | half | Adds 2 bytes to CRC (little endian)                  |
|         |          |   W    | byte | Adds 1 byte to CRC                                   |
|---------|----------|--------|------|------------------------------------------------------|
| 0x0C    | CRCREFL  |   R    | word | Current CRC "reflected" (LSBs and MSBs interchanged) |
|         | DATAREFL |   W    | word | Adds 4 "reflected" bytes to CRC                      |
|         |          |   W    | half | Adds 2 "reflected" bytes to CRC                      |
|         |          |   W    | byte | Adds 1 "reflected" byte to CRC                       |
|---------|----------|--------|------|------------------------------------------------------|

The register CRC holds the current value of the CRC and it has to be written with its initial 
value before doing any CRC calculation. For some communication standards its initial value is 
zero, but there are cases where the initial value is nonzero. This register is 32 bit wide, 
and for CRC polynomials with less than 32 bits its contents have to be MSB aligned. As an 
example lets consider the initialization for the CRC16 of the X25 standard:

CRC=0xFFFF0000;		// Initial value (MSB justified)

In this case only 16 bits are going to be used and the lower 16 bits should be zero.

The POLY register contains the polynomial to use for computations and it also has to be MSB 
aligned. Following the same example, the CRC polynomial for X25 is x^16+x^12+x^5+x^0, 
and that means the POLY value is 0x1021 (bits #12, #5, and #0 as ones), but it has to be MSB 
aligned:

POLY=0x1021<<16;		// Polynomial (MSB justified)

After CRC and POLY are initialized, any write to DATA, or DATAREFL, registers will start 
the CRC processing. But these registers can be written as 8, 16, or 32-bit values, and therefore 
the number of clock cycles used depends on the width of the data. When the CRC is busy the bit #0 
of the STAT register is zero, meaning we have to wait for the result. Writes to the DATAREFL 
register results in the order of the bits being reversed (LSB being sent first). This is what
happens in the X25 example:

DATAREFL32=0x125555ff;   // Little-endian bytes: 0xff, 0x55, 0x55, 0x12
while ((STAT&1)==0);
DATAREFL8=0x55;          // Single byte: 0x55
while ((STAT&1)==0);

In this example a 32-bit, little endian, data, is sent first to the DATA_reflected register. Then 
we wait until the data is processed, and next, a single byte more is also sent to the same register
but using an 8-bit data width. The data width for these registers is defined using the following 
code (listing for DATA register only):

\#define DATA32 (*(volatile uint32_t*)(CRCBASE+8)) 
\#define DATA16 (*(volatile uint16_t*)(CRCBASE+8)) 
\#define DATA8  (*(volatile  uint8_t*)(CRCBASE+8))

Here, any value assigned to the DATA32 symbol will generate an “store_word” instruction, while 
assignments to DATA16 or DATA8 will result in “store_halfword” or “store_byte” instructions 
respectively. 

At the end the CRC result can be read from both the CRC and CRCREFL registers. In the last case 
the result is LSB justified. This is the case for the X25 standard,where the resulting CRC must 
also have its bits inverted:

_printf("crc=0x%04x\n",CRCREFL ^ 0xFFFF);

## How to test

Not "reflected" CRCs (MSB goes first)

- 1  Write the CRC register with the initial value (for example with 0)
- 2  Write the POLY register with the desired polynomial. The valued has to be right aligned. For
     instance, for the typical 16-bit CRC (x^16+x^12+x^5+x^0) its value is: 0x10210000
- 3  Write the data to the DATA register using the appropriate width. For instance, if 8-bit values
     have to be added to the CRC use the SB (Store Byte) instruction by means of a write to the
     DATA8 register.
- 4  Wait until the ready bit in the STAT register goes to one. Keep adding data until the end of
     the block (go to step 3).
- 5  Read the CRC register. The result is in the MSB bits.

"Reflected" CRCs (LSB goes first)

- 1  Write the CRC register with the initial value (for example with 0)
- 2  Write the POLY register with the desired polynomial. The valued has to be right aligned. For
     instance, for the typical 16-bit CRC (x^16+x^12+x^5+x^0) its value is: 0x10210000
- 3  Write the data to the DATAREFL register using the appropriate width. For instance, if 8-bit 
     values have to be added to the CRC use the SB (Store Byte) instruction by means of a write to 
     the DATAREFL8 register.
- 4  Wait until the ready bit in the STAT register goes to one. Keep adding data until the end of
     the block (go to step 3).
- 5  Read the CRCREFL register. The result is in the LSB bits.


## External hardware

No external hardware is required

## References

https://crccalc.com

