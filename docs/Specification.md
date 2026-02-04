# Specification: Symmetric FIR Filter with Decimation by 2

## 1. FIR Filter Basics

A Finite Impulse Response (FIR) filter computes a weighted sum of input samples:

```
y[n] = Σ h[k] * x[n-k]  for k = 0 to N-1
```

Where:
- `x[n]` is the input signal
- `y[n]` is the output signal
- `h[k]` are the filter coefficients (N taps)

## 2. Symmetric Coefficients

A symmetric FIR filter has coefficients where `h[k] = h[N-1-k]`. For a 16-tap filter:
- h[0] = h[15]
- h[1] = h[14]
- h[2] = h[13]
- ... and so on

This means only N/2 unique coefficients are needed (8 for a 16-tap filter).

### Exploiting Symmetry

With symmetric coefficients, the filter equation can be rewritten:

```
y[n] = h[0]*(x[n] + x[n-15]) + h[1]*(x[n-1] + x[n-14]) + ... + h[7]*(x[n-7] + x[n-8])
```

By **pre-adding symmetric sample pairs**, we reduce the number of multiplications by half.

## 3. Decimation by 2

With decimation by 2, only every other output sample is computed. Computing y[2n+1]:

```
y[2n+1] = Σ h[k] * x[2n+1-k]  for k = 0 to 15
```

This means we have 2 input clock cycles available per output sample.

## 4. Polyphase Decomposition

Polyphase decomposition splits the input into separate streams based on sample index parity:
- **Even samples**: x_e[m] = x[2m] → {x[0], x[2], x[4], ...}
- **Odd samples**: x_o[m] = x[2m+1] → {x[1], x[3], x[5], ...}

Each stream is stored in its own shift register, updated on alternate clock cycles.

## 5. Combining Symmetry with Polyphase Decomposition

For output y[2n+1], the sample indices x[2n+1-k] for k=0..15 map to polyphase streams as:

| k | Sample | Polyphase |
|---|--------|-----------|
| 0 | x[2n+1] | x_o[n] |
| 1 | x[2n] | x_e[n] |
| 2 | x[2n-1] | x_o[n-1] |
| 3 | x[2n-2] | x_e[n-1] |
| ... | ... | ... |
| 14 | x[2n-13] | x_o[n-7] |
| 15 | x[2n-14] | x_e[n-7] |

The 8 symmetric pre-additions combine samples at positions k and (15-k):

| Coefficient | Samples Added |
|-------------|---------------|
| h[0] | x[2n+1] + x[2n-14] = x_o[n] + x_e[n-7] |
| h[1] | x[2n] + x[2n-13] = x_e[n] + x_o[n-7] |
| h[2] | x[2n-1] + x[2n-12] = x_o[n-1] + x_e[n-6] |
| h[3] | x[2n-2] + x[2n-11] = x_e[n-1] + x_o[n-6] |
| h[4] | x[2n-3] + x[2n-10] = x_o[n-2] + x_e[n-5] |
| h[5] | x[2n-4] + x[2n-9] = x_e[n-2] + x_o[n-5] |
| h[6] | x[2n-5] + x[2n-8] = x_o[n-3] + x_e[n-4] |
| h[7] | x[2n-6] + x[2n-7] = x_e[n-3] + x_o[n-4] |

## 6. Time-Domain Multiplexing (TDM)

With 2 clock cycles per output (due to decimation), 4 multipliers can compute all 8 products:
- **Phase 0**: Compute 4 products (e.g., using h[0], h[2], h[4], h[6])
- **Phase 1**: Compute 4 products (e.g., using h[1], h[3], h[5], h[7])
- Accumulate partial sums across phases

## 7. Bitwidth Requirements

| Signal | Width |
|--------|-------|
| Input samples | 8-bit signed |
| Coefficients | 8-bit signed |
| Pre-addition sum | 9-bit signed |
| Single product | 17-bit signed |
| Sum of 4 products | 19-bit signed |
| Final output | 20-bit signed |
