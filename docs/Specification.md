# Specification: 16-Tap Symmetric FIR Filter with Decimation by 2

## 1. Overview

This document specifies the implementation of an **area-optimized symmetric FIR filter** with decimation by 2. The design exploits:
1. **Coefficient symmetry** to pre-add sample pairs before multiplication
2. **Polyphase decomposition** for decimation
3. **Time-domain multiplexing** to reuse multipliers

This reduces the required multipliers from 16 (naive) → 8 (symmetric) → **4 multipliers** (polyphase + TDM).

## 2. Mathematical Background

### 2.1 Symmetric FIR Filter

A 16-tap symmetric FIR filter has coefficients where h[k] = h[15-k]:
- h[0] = h[15]
- h[1] = h[14]
- h[2] = h[13]
- h[3] = h[12]
- h[4] = h[11]
- h[5] = h[10]
- h[6] = h[9]
- h[7] = h[8]

This means only **8 unique coefficients** are needed.

The standard FIR output:
```
y[n] = h[0]*x[n] + h[1]*x[n-1] + ... + h[15]*x[n-15]
```

With symmetry, this becomes:
```
y[n] = h[0]*(x[n] + x[n-15]) + h[1]*(x[n-1] + x[n-14]) + ... + h[7]*(x[n-7] + x[n-8])
```

By **pre-adding symmetric sample pairs**, we reduce from 16 multiplications to 8.

### 2.2 Decimation by 2

With decimation by 2, we output on odd-indexed samples:
```
y[2n+1] = Σ h[k] * x[2n+1-k]  for k = 0 to 15
```

### 2.3 Polyphase Decomposition

Split the input into even and odd sample streams:
- **Even samples**: x_e[m] = x[2m] → {x[0], x[2], x[4], ...}
- **Odd samples**: x_o[m] = x[2m+1] → {x[1], x[3], x[5], ...}

### 2.4 Combined Symmetric + Polyphase

For output y[2n+1], the symmetric sample pairs map to the polyphase registers as:

| Coefficient | Sample Pair | Polyphase Mapping |
|-------------|-------------|-------------------|
| h[0] | x[2n+1] + x[2n-14] | x_o[n] + x_e[n-7] |
| h[1] | x[2n] + x[2n-13] | x_e[n] + x_o[n-7] |
| h[2] | x[2n-1] + x[2n-12] | x_o[n-1] + x_e[n-6] |
| h[3] | x[2n-2] + x[2n-11] | x_e[n-1] + x_o[n-6] |
| h[4] | x[2n-3] + x[2n-10] | x_o[n-2] + x_e[n-5] |
| h[5] | x[2n-4] + x[2n-9] | x_e[n-2] + x_o[n-5] |
| h[6] | x[2n-5] + x[2n-8] | x_o[n-3] + x_e[n-4] |
| h[7] | x[2n-6] + x[2n-7] | x_e[n-3] + x_o[n-4] |

### 2.5 Time-Domain Multiplexing with 4 Multipliers

Since decimation by 2 provides 2 clock cycles per output, use **4 multipliers** over 2 phases:

- **Phase 0**: Compute products for h[0], h[2], h[4], h[6] (even-indexed coefficients)
- **Phase 1**: Compute products for h[1], h[3], h[5], h[7] (odd-indexed coefficients)

Accumulate partial sums and output the final result.

## 3. Bitwidth Analysis

### 3.1 Input and Coefficient Widths
| Signal | Width | Range |
|--------|-------|-------|
| Input (x_in) | 8-bit signed | [-128, +127] |
| Coefficients (h[k]) | 8-bit signed | [-128, +127] |

### 3.2 Intermediate Calculations

| Operation | Width | Calculation |
|-----------|-------|-------------|
| Pre-addition (x[i] + x[j]) | 9-bit signed | 8 + 1 = 9 bits |
| Single multiplication | 17-bit signed | 8 + 9 = 17 bits |
| Sum of 4 products | 19-bit signed | 17 + 2 = 19 bits |
| Sum of 8 products | **20-bit signed** | 17 + 3 = 20 bits |

### 3.3 Output Width
The final output `y_out` must be **20 bits signed**.

## 4. Filter Coefficients

The filter uses symmetric coefficients (only 8 unique values):

```
H0 = H15 = 2
H1 = H14 = 4
H2 = H13 = 6
H3 = H12 = 10
H4 = H11 = 14
H5 = H10 = 20
H6 = H9  = 26
H7 = H8  = 32
```

## 5. Implementation Requirements

1. **Polyphase shift registers**: Separate 8-deep registers for odd and even samples
2. **Symmetric pre-adders**: 8 adders to compute sample pairs
3. **4 multipliers**: Time-multiplexed between even/odd coefficient groups
4. **Coefficient/sample muxing**: Select appropriate pairs based on computation phase
5. **Accumulator**: Store partial sum from first phase
6. **Reset**: Active-low asynchronous reset
7. **Output timing**: New valid output every 2 clock cycles (decimation by 2)
