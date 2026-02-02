# FIR Filter with Decimation by 2

16-tap FIR filter with decimation by 2 using polyphase decomposition.

## Problem Description

Implement a high-speed 16-tap FIR filter that:
- Uses polyphase decomposition to relax critical path timing
- Decimates output by factor of 2
- Uses ICG (Integrated Clock Gating) for power savings

## Directory Structure

```
├── sources/           # Verilog RTL source files
│   └── fir_filter_dec2.v
├── tests/             # Cocotb test files
│   └── test_fir_filter_dec2.py
├── docs/              # Specifications
│   └── Specification.md
├── prompt.txt         # Task description
└── pyproject.toml     # Python dependencies
```

## Running Tests

```bash
pytest tests/test_fir_filter_dec2.py -v
```
