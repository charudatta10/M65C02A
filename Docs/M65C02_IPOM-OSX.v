////////////////////////////////////////////////////////////////////////////////
//
//  M65C02A soft-core module for M65C02A soft-core microcomputer project.
// 
//  Copyright 2013-2014 by Michael A. Morris, dba M. A. Morris & Associates
//
//  All rights reserved. The source code contained herein is publicly released
//  under the terms and conditions of the GNU General Public License as conveyed
//  in the license provided below.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program.  If not, see <http://www.gnu.org/licenses/>, or write to
//
//  Free Software Foundation, Inc.
//  51 Franklin Street, Fifth Floor
//  Boston, MA  02110-1301 USA
//
//  Further, no use of this source code is permitted in any form or means
//  without inclusion of this banner prominently in any derived works.
//
//  Michael A. Morris <morrisma_at_mchsi_dot_com>
//  164 Raleigh Way
//  Huntsville, AL 35811
//  USA
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 100ps

////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates 
// Engineer:        Michael A. Morris 
// 
// Create Date:     07:11:26 12/01/2014 
// Design Name:     WDC W65C02 Microprocessor Re-Implementation
// Module Name:     M65C02_IPOM.v
// Project Name:    C:\XProjects\ISE10.1i\M65C02A 
// Target Devices:  Generic SRAM-based FPGA 
// Tool versions:   Xilinx ISE10.1i SP3
//
// Description:
//
//  This module provides the implementation of the M65C02A prefix instructions.
//  The module captures and processes the instruction decoder fields that iden-
//  tify the prefix instructions for the M65C02A ISA. There are three classes of
//  prefix instructions: (1) address modifier, (2) operation size modifier, and
//  (3) register override modifiers.
//
//  Six opcodes are provided to support the prefix instructions. Three opcodes
//  support the register override prefix instruction class: OAX, OAY, and OSX.
//  One opcode, IND, supports the address modifier prefix instruction class, and
//  one opcode, SIZ, supports the operation size prefix instruction class. The
//  address modifier and operation size modifier prefix instructions are expect-
//  ed to be more heavily used, so one opcode simultaneously generates the IND 
//  and SIZ prefix instructions: ISZ.
//  
//  The objective of the prefix instructions is to improve the orthogonality and
//  functionality of the standard instruction set of the M65C02A, which is com-
//  patible with the instruction set of the WDC W65C02S microprocessor. All of
//  the prefix instructions defined operate on a single normal instruction.
//  Multiple prefix instructions may be prepended to a single instruction, but
//  some of their effects are mutually exclusive and extend only to the comple-
//  tion of a normal instruction whether it is a standard or extended M65C02A
//  instruction.
//
//  IND converts direct addressing into indirect addressing for most instruc-
//  tions. IND is ignored if prepended to a normal instruction opcode for which
//  the addressing mode change implied by its presence already exists. For exam-
//  ple, IND is ignored in the instruction sequence IND ORA zp,X because the re-
//  sulting instruction ORA (zp,X) is a supported addressing mode of the ORA in-
//  struction. When IND is prepended to an instruction that does not provide an
//  indexed indirect addressing mode, the indexed indirect addressing mode gene-
//  rated depends on the index register. If the index register is X, then a pre-
//  indexed indirect addressing mode is generated. If the index register is Y,
//  then a post-indexed indirect addressing mode is generated.
//
//  SIZ converts an 8-bit operation into a 16-bit operation. Like all prefix
//  instructions, the effects of SIZ only extend to the following instruction.
//  (Note: SIZ is not currently supported by the M65C02A ALU or microprogram.)
//  ISZ applies IND and SIZ to the following instructions. The restrictions and
//  effects of IND and SIZ apply.
//
//  OAX swaps the A and X registers. This allows X to be used as an accumulator
//  and A as an index register. X replaces A in all accumulator operations, and
//  A replaces X in all index operations.
//
//  OAY swaps the A and Y registers. This allows Y to be used as an accumulator
//  and A as an index register. Y replaces A in all accumulator operations, and
//  A replaces Y in all index operations.
//
//  OSX swaps the X and S registers. X replaces S as the stack pointer. Thus,
//  OSX allows a second stack, implemented in hardware instead of software, to
//  be implemented in zero page memory. When OSX is prepended to an instruction,
//  X provides all of the stack operations normally associated with S, including
//  the M65C02A-specific stack relative instructions and the 16-bit push/pop in-
//  structions.
//
//  OAX is mutually exclusive with OAX. If OAX and OAY are both prepended to an
//  instruction, the effects applied to the instruction are those of the prefix
//  instruction nearest to the instruction itself. OSX and OAX are also mutually
//  exclusive. OAY and OSX may be used together, and their effects are insensi-
//  tive to the order in which they are prepended. IND, SIZ, and ISZ may be com-
//  bined with OAX, OAY, OSX, or OSX OAY.
//
//  The prefix instructions are expected to be generated using macros when pro-
//  gramming the M65C02A in assembly language, or by compiler code generators.
//  In either case, it is not expected that strings of incorrect or invalid pre-
//  fix instructions will be found in the instruction stream. It is possible to
//  modify the core to generate an invalid instruction trap when incorrect or
//  invalid sequences of prefix instructions are used, but at this point, it is
//  assumed that the assembly language programmer or compiler writer does not
//  generate incorrect or invalid prefix instruction sequences.
//
//  Furthermore, all of the prefix instructions are taken from the unused column
//  B opcodes of a standard W65C02S, and thus act as single cycle instructions.
//
//  The overall objective for the extended instructions, including the prefix
//  instructions, in the M65C02A is that they don't affect the behavior of
//  existing programs and tools. Thus, an existing 6502/65C02 program should be
//  properly executed by the M65C02A. Similarly, it is expected that a standard
//  6502/65C02 assembler will generate programs that will be executed correctly
//  by the M65C02A without resorting to the use of any special coding standards.
//
// Dependencies:    none
//
// Revision: 
//
//  1.00    14L01   MAM     Initial creation.
//
//  Other Comments:
//
//  The effects of the OAX/OAY register override prefix instructions are shown
//  in the following table:
//
//        Standard               OAX Prefix                 OAY Prefix
//  ORA/ANL/EOR/ADC zp       ORX/ANX/EOX/ACX zp         ORY/ANY/EOY/ACY zp
//  STA/LDA/CMP/SBC zp       STX/LDX/CPX/SCX zp         STY/LDY/CPY/SCY zp
//  STX/LDX/CPX     zp       STA/LDA/CMP     zp
//  STY/LDY/CPY     zp                                  STA/LDA/CMP     zp
//  BIT/TSB/TRB     zp       BIT/TSB/TRB     zp:X       BIT/TSB/TRB     zp:Y
//  ASL/ROL/LSR/ROR zp
//  INC/DEC         zp
//  STZ             zp
//  PHW/PLW         zp
//  RMBx/SMBx       zp
//  BBRx/BBSx       zp,rel8
//  ORA/ANL/EOR/ADC zp,X     ORX/ANX/EOX/ACX zp,A       ORY/ANY/EOY/ACY zp,X
//  STA/LDA/CMP/SBC zp,X     STX/LDX/CPX/SCX zp,A       STY/LDY/CPY/SCY zp,X
//  STY/LDY         zp,X                                STA/LDA         zp,X
//  BIT             zp,X     BIT             zp,A:X     BIT             zp,X:Y
//  ASL/ROL/LSR/ROR zp,X     ASL/ROL/LSR/RPR zp,A
//  INC/DEC         zp,X     INC/DEC         zp,A
//  STZ             zp,X     STZ             zp,A
//  ORA/ANL/EOR/ADC zp,Y     ORX/ANX/EOX/ACX zp,Y
//  STA/LDA/CMP/SBC zp,Y     STX/LDX/CPX/SCX zp,Y
//  STX/LDX         zp,Y     STA/LDA         zp,Y               
//  ORA/ANL/EOR/ADC (zp,X)   ORX/ANX/EOX/ACX (zp,A)     ORY/ANY/EOY/ACY (zp,X)
//  STA/LDA/CMP/SBC (zp,X)   STX/LDX/CPX/SCX (zp,A)     STY/LDY/CPY/SCY (zp,X)
//  ORA/ANL/EOR/ADC (zp),Y   ORX/ANX/EOX/ACX (zp),Y     ORY/ANY/EOY/ACY (zp),A
//  STA/LDA/CMP/SBC (zp),Y   STX/LDX/CPX/SCX (zp),Y     STY/LDY/CPY/SCY (zp),A
//  ORA/ANL/EOR/ADC sp,S     ORX/ANX/EOX/ACX sp,S       ORY/ANY/EOY/ACY sp,S
//  STA/LDA/CMP/SBC sp,S     STX/LDX/CPX/SCX sp,S       STY/LDY/CPY/SCY sp,S
//  ORA/ANL/EOR/ADC (sp,S),Y ORX/ANX/EOX/ACX (sp,S),Y   ORY/ANY/EOY/ACY (sp,S),A
//  STA/LDA/CMP/SBC (sp,S),Y STX/LDX/CPX/SCX (sp,S),Y   STY/LDY/CPY/SCY (sp,S),A 
//  JSR/JMP         (sp,S),Y JSR/JMP         (sp,S),Y
//  ORA/AND/EOR/ADC #imm8    ORX/ANX/EOX/ACX #imm8      ORY/ANY/EOY/ACY #imm8
//      LDA/CMP/SBC #imm8        LDX/CPX/SCX #imm8          LDY/CPY/SCY #imm8
//      LDX/CPX     #imm8        LDA/CPA     #imm8
//      LDY/CPY     #imm8                                   LDA/CMP     #imm8
//  BIT             #imm8    BIT             #imm8:X    BIT             #imm8:Y
//  BRK/COP         #imm8
//  PHW             #imm16
//  PHR             rel16
//  BRL/BSR         rel16
//  BRA             rel8
//  BPL/BMI/BVC/BVS rel8      
//  BCC/BCS/BNE/BEQ rel8      
//  RTS/RTI                   
//  CLC/SEC/CLI/SEI           
//  CLD/SED/CLV               
//  ASL/ROL/LSR/ROR A        ASL/ROL/LSR/ROR X          ASL/ROL/LSR/ROR Y
//  INC/DEC         A
//  INX/DEX
//  INY/DEY
//  PHA/PLA
//  PHP/PLP
//  PHX/PLX
//  PHY/PLY
//  TXA/TAX
//  TYA/TAY
//  TSX/TXS
//  NOP
//  ORA/ANL/EOR/ADC abs      ORX/ANX/EOX/ACX abs        ORY/ANY/EOY/ACY abs
//  STA/LDA/CMP/SBC abs      STX/LDX/CPX/SCX abs        STY/LDY/CPY/SCY abs
//  STX/LDX/CPX     abs      STA/LDA/CPA     abs
//  STY/LDY/CPY     abs                                 STA/LDA/CMP     abs
//  BIT/TSB/TRB     abs      BIT/TSB/TRB     abs:X      BIT/TSB/TRB     abs:Y 
//  ASL/ROL/LSR/ROR abs
//  INC/DEC         abs
//  STZ             abs
//  PHW/PLW         abs
//  JSR/JMP         abs
//  ORA/ANL/EOR/ADC abs,X    ORX/ANX/EOX/ACX abs,A      ORY/ANY/EOY/ACY abs,X
//  STA/LDA/CMP/SBC abs,X    STX/LDX/CPX/SCX abs,A      STY/LDY/CPY/SCY abs,X
//  STY/LDY         abs,X                               STA/LDA         abs,X
//  BIT             abs,X    BIT             abs,A:X    BIT             abs,A:Y
//  ASL/ROL/LSR/ROR abs,X    ASL/ROL/LSR/ROR abs,A
//  INC/DEC         abs,X    INC/DEC         abs,A
//  STZ             abs,X    STZ             abs,A
//  ORA/ANL/EOR/ADC abs,Y    ORX/ANX/EOX/ACX abs,Y      ORY/ANY/EOY/ACY abs,A
//  STA/LDA/CMP/SBC abs,Y    STX/LDX/CPX/SCX abs,Y      STY/LDY/CPY/SCY abs,A
//      LDX         abs,Y        LDA         abs,Y
//  JMP             abs
//  JMP             (abs)
//  JMP             (abs,X)  JMP             (abs,A)
//  
//  The effects of the OSY register override prefix instruction and the IND 
//  addressing mode modifier prefix instructions are shown in the following
//  table:
//
//        Standard               OSX Prefix                 IND
//  ORA/ANL/EOR/ADC zp
//  STA/LDA/CMP/SBC zp
//  STX/LDX/CPX     zp       STS/LDS/CPS     zp         STX/LDX/CPX     (zp)     
//  STY/LDY/CPY     zp                                  STY/LDY/CPY     (zp)     
//  BIT/TSB/TRB     zp                                  BIT/TSB/TRB     (zp)     
//  ASL/ROL/LSR/ROR zp                                  ASL/ROL/LSR/ROR (zp)     
//  INC/DEC         zp                                  INC/DEC         (zp)     
//  STZ             zp                                  STZ             (zp)     
//  PHW/PLW         zp                                  PHW/PLW         (zp)     
//  RMBx/SMBx       zp                                  RMBx/SMBx       (zp)     
//  BBRx/BBSx       zp,rel8                             BBRx/BBSx       (zp),rel
//  ORA/ANL/EOR/ADC zp,X
//  STA/LDA/CMP/SBC zp,X     ---/---/---     zp,X       
//  STY/LDY         zp,X                                STY/LDY         (zp),X
//  BIT             zp,X                                BIT             (zp),X
//  ASL/ROL/LSR/ROR zp,X                                ASL/ROL/LSR/ROR (zp),X
//  INC/DEC         zp,X                                INC/DEC         (zp),X
//  STZ             zp,X                                STZ             (zp),X
//  ORA/ANL/EOR/ADC zp,Y
//  STA/LDA/CMP/SBC zp,Y
//  STX/LDX         zp,Y                                STX/LDX         (zp),Y
//  ORA/ANL/EOR/ADC (zp,X)
//  STA/LDA/CMP/SBC (zp,X)
//  ORA/ANL/EOR/ADC (zp),Y                              ORA/ANL/EOR/ADC ((zp)),Y
//  STA/LDA/CMP/SBC (zp),Y                              STA/LDA/CMP/SBC ((zp)),Y                                  
//  ORA/ANL/EOR/ADC sp,S     ORA/ANL/EOR/ADC sp;X       ORA/ANL/EOR/ADC (sp,S)
//  STA/LDA/CMP/SBC sp,S     STA/LDA/CMP/SBC sp;X       STA/LDA/CMP/SBC (sp,S)
//  ORA/ANL/EOR/ADC (sp,S),Y ORA/ANL/EOR/ADC (sp;X),Y   ORA/ANL/EOR/ADC ((sp;X)),Y   
//  STA/LDA/CMP/SBC (sp,S),Y STA/LDA/CMP/SBC (sp;X),Y   STA/LDA/CMP/SBC ((sp;X)),Y 
//  JSR/JMP         (sp,S),Y JSR/JMP         (sp;X),Y   JSR/JMP         ((sp;X)),Y
//  ORA/ANL/EOR/ADC #imm8
//      LDA/CMP/SBC #imm8
//      LDX/CPX     #imm8        LDS/CPS     #imm8
//      LDY/CPY     #imm8
//  BIT             #imm8
//  BRK/COP         #imm8
//  PHW             #imm16
//  PHR             rel16
//  BRL/BSR         rel16
//  BRA             rel8
//  BPL/BMI/BVC/BVS rel8      
//  BCC/BCS/BNE/BEQ rel8      
//  RTS/RTI                   
//  CLC/SEC/CLI/SEI           
//  CLD/SED/CLV               
//  ASL/ROL/LSR/ROR A
//  INC/DEC         A
//  INX/DEX                  INS/DES
//  INY/DEY          
//  PHA/PLA
//  PHP/PLP
//  PHX/PLX                  PHS/PLS
//  PHY/PLY
//  TXA/TAX                  TSA/TAS                          
//  TYA/TAY
//  TSX/TXS
//  NOP
//  ORA/ANL/EOR/ADC abs                                 ORA/ANL/EOR/ADC (abs)
//  STA/LDA/CMP/SBC abs                                 STA/LDA/CMP/SBC (abs)
//  STX/LDX/CPX     abs      STS/LDS/CPS     abs        STX/LDX/CPX     (abs)
//  STY/LDY/CPY     abs                                 STY/LDY/CPY     (abs)
//  BIT/TSB/TRB     abs                                 BIT/TSB/TRB     (abs)
//  ASL/ROL/LSR/ROR abs                                 ASL/ROL/LSR/ROR (abs)
//  INC/DEC         abs                                 INC/DEC         (abs)
//  STZ             abs                                 STZ             (abs)  
//  PHW/PLW         abs                                 PHW/PLW         (abs)  
//  JSR/JMP         abs                                 JSR/JMP         (abs)  
//  ORA/ANL/EOR/ADC abs,X                               ORA/ANL/EOR/ADC (abs),X
//  STA/LDA/CMP/SBC abs,X                               STA/LDA/CMP/SBC (abs),X
//  STY/LDY         abs,X    ---/---         abs,X      STY/LDY         (abs),X
//  BIT             abs,X                               BIT             (abs),X
//  ASL/ROL/LSR/ROR abs,X                               ASL/ROL/LSR/ROR (abs),X
//  INC/DEC         abs,X                               INC/DEC         (abs),X
//  STZ             abs,X                               STZ             (abs),X
//  ORA/ANL/EOR/ADC abs,Y                               ORA/ANL/EOR/ADC (abs),Y
//  STA/LDA/CMP/SBC abs,Y                               STA/LDA/CMP/SBC (abs),Y
//      LDX         abs,Y                                   LDX         (abs),Y
//  JMP             abs                                                      
//  JMP             (abs)                               JMP             ((abs))                                                    
//  JMP             (abs,X)                             JMP             ((abs)),X                     
//                                                                           
//  ////////////////////////////////////////////////////////////////////////////
//
//           A   X   Y   S 
//          --- --- --- --- 
//  OAX :    X   A   Y   S  -- Acc: X, Pre-Index: A, Post-Index: Y, Stack Ptr: S 
//  OAY :    Y   X   A   S  -- Acc: Y, Pre-Index: X, Post-Index: A, Stack Ptr: S   
//  OSX :    A   S   Y   X  -- Acc: A, Pre-Index: -, Post-Index: Y, Stack Ptr: X  
//
//          PHA PLA PHP PLP PHX PLX PHY PLY
//          --- --- --- --- --- --- --- ---
//  OAX :    A   A   P   P   X   X   Y   Y
//  OAY :    A   A   P   P   X   X   Y   Y
//  OSX :    A   A   P   P   S   S   Y   Y
//
//          TXA TAX TYA TAY TSX TXS
//          --- --- --- --- --- ---
//  OAX :   TXA TAX TYA TAY TSX TXS
//  OAY :   TXA TAX TYA TAY TSX TXS
//  OSX :   TSA TAS TYA TAY TXS TSX
//
//  Notes:
//
////////////////////////////////////////////////////////////////////////////////

module M65C02_IPOM (
    input Rst,
    input Clk,
    
    input Rdy,
    input Sync,

    input [2:0] iReg_WE,

    input [2:0] iMode,
    input [7:0] iOpCode,
    input [2:0] iWSel,
    input [2:0] iOSel,

    output IND,
    output SIZ,
    output OAX,
    output OAY,
    output OSX,
    
    output [2:0] oReg_WE,
    output [2:0] oWSel,
    output [2:0] oOSel
);

////////////////////////////////////////////////////////////////////////////////
//
//  Declarations
//

////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//



endmodule
