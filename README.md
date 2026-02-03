# FIR Filter with Decimation by 2 (Area-Efficient)

Area-efficient 16-tap FIR filter with decimation by 2 using time-domain multiplexing.

## Problem Description

Implement an area-efficient 16-tap FIR filter that:
- Uses polyphase decomposition to split computation into P_odd and P_even
- Uses time-domain multiplexing to reuse 8 multipliers (instead of 16)
- Computes P_even on even clock cycles, P_odd on odd clock cycles
- Achieves 50% multiplier area savings

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
