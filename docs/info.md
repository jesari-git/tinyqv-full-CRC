<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## What it does

This peripheral is a CRC accelerator. 

## Register map

Document the registers that are used to interact with your peripheral.
All registers are 32-bit wide and are located at addresses multiple of 4:

| Address | Name     | Access | size | Description                                          |
|---------|----------|--------|------|------------------------------------------------------|
| 0x00    | CRC      |  R/W   | word | Current CRC value, right aligned                     |
|---------|----------|--------|------|------------------------------------------------------|
| 0x04    | POLY     |  R/W   | word | CRC polynomial, right aligned, LSBs padded with 0s   |
|---------|----------|--------|------|------------------------------------------------------|
| 0x08    | DATA     |   W    | word | Adds 4 bytes to CRC (little endian)                  |
|         |          |   W    | half | Adds 2 bytes to CRC (little endian)                  |
|         |          |   W    | byte | Adds 1 byte to CRC                                   |
|---------|----------|--------|------|------------------------------------------------------|
| 0x0C    | CRCREFL  |   R    | word | Current CRC "reflected" (LSBs and MSBs interchanged) |
|         | DATAREFL |   W    | word | Adds 4 "reflected" bytes to CRC                      |
|         |          |   W    | half | Adds 2 "reflected" bytes to CRC                      |
|         |          |   W    | byte | Adds 1 "reflected" byte to CRC                       |
|---------|----------|--------|------|------------------------------------------------------|

## How to test



## External hardware

No external hardware is required

