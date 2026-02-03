# Specification: 16-Tap FIR Filter with Decimation by 2 using Time-Domain Multiplexing

## 1. Overview

This document specifies the implementation of an **area-efficient** FIR filter with decimation by 2. The design uses **time-domain multiplexing** to reuse multipliers across clock cycles, reducing the number of required multipliers from 16 to 8.

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

### 2.4 Time-Domain Multiplexing for Area Efficiency

**Key Insight**: Since we have 2 clock cycles per output (due to decimation by 2), we can compute the two partial sums sequentially using the same set of 8 multipliers.

**Architecture**:
- **Clock cycle 0 (even input)**: Compute P_even using 8 multipliers with odd-indexed coefficients (H1, H3, H5, H7, H9, H11, H13, H15)
- **Clock cycle 1 (odd input)**: Compute P_odd using the SAME 8 multipliers with even-indexed coefficients (H0, H2, H4, H6, H8, H10, H12, H14)
- **Output**: Sum of P_even (registered) + P_odd

**Area Savings**: This reduces multiplier count from 16 to 8, saving 50% multiplier area.

**Trade-off**: The multipliers are active every clock cycle (no timing relaxation), but the area is significantly reduced.

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
