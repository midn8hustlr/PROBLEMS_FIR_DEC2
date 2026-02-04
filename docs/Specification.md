# Background: Symmetric FIR Filters with Decimation

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

## 3. Decimation

Decimation reduces the output sample rate. With decimation by 2, only every other output sample is computed:

```
y[2n+1] = Σ h[k] * x[2n+1-k]  for k = 0 to 15
```

This means we have 2 input clock cycles available per output sample.

## 4. Polyphase Decomposition

Polyphase decomposition splits the input into separate streams based on sample index parity:
- **Even samples**: x_e[m] = x[2m] → {x[0], x[2], x[4], ...}
- **Odd samples**: x_o[m] = x[2m+1] → {x[1], x[3], x[5], ...}

Each stream is stored in its own shift register, updated on alternate clock cycles.

## 5. Time-Domain Multiplexing (TDM)

When decimation provides multiple clock cycles per output, multipliers can be shared across cycles:
- Cycle 1: Compute partial products with first set of coefficients
- Cycle 2: Compute partial products with second set of coefficients
- Accumulate results across cycles

This trades computation time for reduced hardware area.

## 6. Bitwidth Considerations

For signed arithmetic:
- Pre-addition of two N-bit values requires N+1 bits
- Multiplication of A-bit and B-bit values produces (A+B)-bit result
- Summing M products requires log2(M) additional bits for the accumulator
