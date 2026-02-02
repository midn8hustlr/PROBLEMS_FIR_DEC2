# Specification: 16-Tap FIR Filter with Decimation by 2 using Polyphase Decomposition

## 1. Overview

This document specifies the implementation of FIR filter with decimation by 2. The design uses **polyphase decomposition** to perform computation at output data rate, i.e. half the input clock frequency thereby relaxing the critical path for high speed design.

## 2. Mathematical Background

### 2.1 Standard FIR Filter

A 16-tap FIR filter computes:

```
y[n] = Σ h[k] * x[n-k]  for k = 0 to 15
     = h[0]*x[n] + h[1]*x[n-1] + h[2]*x[n-2] + ... + h[15]*x[n-15]
```

### 2.2 Decimation by 2

With decimation by 2, we only output every other sample. If we output on odd-indexed samples (after receiving x[1], x[3], x[5], ...):

```
y[1] = h[0]*x[1] + h[1]*x[0] + h[2]*x[-1] + ...
y[3] = h[0]*x[3] + h[1]*x[2] + h[2]*x[1] + h[3]*x[0] + ...
y[2n+1] = Σ h[k] * x[2n+1-k]  for k = 0 to 15
```

### 2.3 Polyphase Decomposition

The key insight is that we can split the input sequence into even and odd samples:
- **Even samples**: x_e[m] = x[2m] → {x[0], x[2], x[4], ...}
- **Odd samples**: x_o[m] = x[2m+1] → {x[1], x[3], x[5], ...}

Expanding y[2n+1]:

```
y[2n+1] = h[0]*x[2n+1] + h[1]*x[2n] + h[2]*x[2n-1] + h[3]*x[2n-2] + ...
```

Grouping by even and odd indexed coefficients:

```
y[2n+1] = [h[0]*x[2n+1] + h[2]*x[2n-1] + h[4]*x[2n-3] + h[6]*x[2n-5] + 
           h[8]*x[2n-7] + h[10]*x[2n-9] + h[12]*x[2n-11] + h[14]*x[2n-13]]
        + [h[1]*x[2n] + h[3]*x[2n-2] + h[5]*x[2n-4] + h[7]*x[2n-6] +
           h[9]*x[2n-8] + h[11]*x[2n-10] + h[13]*x[2n-12] + h[15]*x[2n-14]]
```

This can be rewritten as:

```
y[2n+1] = P_odd(n) + P_even(n)

Where:
P_odd(n)  = h[0]*x_o[n] + h[2]*x_o[n-1] + h[4]*x_o[n-2] + h[6]*x_o[n-3] +
            h[8]*x_o[n-4] + h[10]*x_o[n-5] + h[12]*x_o[n-6] + h[14]*x_o[n-7]

P_even(n) = h[1]*x_e[n] + h[3]*x_e[n-1] + h[5]*x_e[n-2] + h[7]*x_e[n-3] +
            h[9]*x_e[n-4] + h[11]*x_e[n-5] + h[13]*x_e[n-6] + h[15]*x_e[n-7]
```

**Key Result**: Each partial sum uses only 8 coefficients and 8 samples. So total multipliers and adders are same as normal FIR filter, but since these odd and even parital sums only update at every other clock cycle, it can help in relaxing the critical path, thereby allowing the design to get synthesized at 2x the clock frequency.

## 3. Bitwidth Analysis

### 3.1 Input and Coefficient Widths
| Signal | Width | Range |
|--------|-------|-------|
| Input (x_in) | 8-bit signed | [-128, +127] |
| Coefficients (h[k]) | 8-bit signed | [-128, +127] |

### 3.2 Intermediate Calculations

| Operation | Width | Calculation |
|-----------|-------|-------------|
| Single multiplication | 16-bit signed | 8 + 8 = 16 bits |
| Sum of 8 products | 19-bit signed | 16 + ceil(log2(8)) = 16 + 3 = 19 bits |
| Sum of 16 products | **20-bit signed** | 16 + ceil(log2(16)) = 16 + 4 = 20 bits |

### 3.3 Output Width
The final output `y_out` must be **20 bits signed** to accommodate the full dynamic range without overflow.
