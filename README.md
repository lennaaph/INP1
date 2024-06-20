# Design of computer systems - 1.project

## BrainF*ck Processor Implementation in VHDL

### Project Overview

This project involves the development of a simple processor using VHDL that can execute programs written in an extended version of the BrainF*ck language. The processor will interpret and execute a set of predefined commands.

## Architecture

The CPU architecture is organized into several key components:

- **Program Counter (PC)**: Manages the instruction pointer, incrementing or decrementing based on control flow.
- **Pointer Register (PTR)**: Points to the current data cell in the memory.
- **Counter Register (CNT)**: Used for loop counting and control.
- **Multiplexers (MUXes)**: Select between different data sources and control signals.
- **Finite State Machine (FSM)**: Controls the state transitions and operations of the CPU.


## FSM State Descriptions

The FSM controls the CPU's operation through various states. Key states include:

- `state_start`: Initialization state, preparing for the next instruction.
- `state_fetch`: Fetches the current instruction from memory.
- `state_decode`: Decodes the fetched instruction and determines the next state.
- `point_inc`, `point_dec`: Handle `>` and `<` commands.
- `prog_inc`, `prog_dec`: Handle `+` and `-` commands.
- `while_start`, `while_end`: Manage loops with `[` and `]`.
- `do_while_start`, `do_while_end`: Manage loops with `(` and `)`.
- `putchar_out`: Handles the `.` output command.
- `getchar_in`: Handles the `,` input command.
- `null_return`: End of program or no-operation state.

Each state corresponds to a specific function and transitions to other states based on the current instruction and CPU conditions.
