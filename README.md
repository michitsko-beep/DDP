# FPGA Sign Language Recognition Accelerator 🚀

> FPGA-accelerated Sign Language Recognition inference system implemented on the K5 / SLRX platform.  
> The project accelerates a neural-network-style pipeline using dedicated hardware accelerators for convolution, pooling, linear layers, and final ArgMax classification.

---

## 🧠 Project Abstract & Key Results

This project implements an FPGA-accelerated Sign Language Recognition inference pipeline on the K5 / SLRX platform.  
The system receives a sign-language image, processes it through convolution, pooling, fully connected layers, and final ArgMax classification, and outputs the detected text.

The main objective was to reduce inference latency by accelerating the compute-heavy neural-network stages in hardware, while preserving full functional correctness on both simulation and real FPGA execution.

## 📊 Measured Results

### Before vs. After Acceleration

The most important evaluation criterion in this project is the performance improvement achieved by hardware acceleration.

The table below compares the baseline implementation (before acceleration) against the FPGA-accelerated implementation (after acceleration).

> **Note:**  
> The accelerated values below were measured directly from the FPGA performance run (`-itr 1`).  
> If baseline software-only / non-accelerated cycle counts are available, they should be added in the **Before Acceleration** column.

| Stage | Before Acceleration (cycles) | After Acceleration (cycles) | Speedup |
|---|---:|---:|---:|
| Conv0 | TBD | 1,147 | TBD |
| Pool0 | TBD | 570 | TBD |
| Conv1 | TBD | 293 | TBD |
| Pool1 | TBD | 273 | TBD |
| Linear0 | TBD | 273 | TBD |
| Linear1 | TBD | 253 | TBD |
| Select / ArgMax | TBD | 289 | TBD |
| **Total** | **TBD** | **3,098** | **TBD** |

### Accelerated FPGA Performance Summary

From the FPGA single-detection performance run, the measured per-stage cycle counts were:

- **Conv0:** 1,147 cycles
- **Pool0:** 570 cycles
- **Conv1:** 293 cycles
- **Pool1:** 273 cycles
- **Linear0:** 273 cycles
- **Linear1:** 253 cycles
- **Select / ArgMax:** 289 cycles
- **Total:** 3,098 cycles

### Functional Output

The FPGA-accelerated design also preserved functional correctness.

| Test Type | Result |
|---|---|
| Single FPGA detection output | `h` |
| FPGA functional success | 100% |
| FPGA functional detected sentence | `have a great weekend` |
| Simulation functional detected sentence | `we are the champions` |

### Synthesis and Timing Results

| Metric | Result |
|---|---:|
| SLRX synthesis logic elements | 15,075 |
| SLRX synthesis achieved frequency | 51.46 MHz |
| Full FPGA logic elements | 27,045 |
| Full FPGA applied clock target | 50 MHz |
| Full FPGA maximum reported frequency | 49.82 MHz |

### LST / Speed Loop Test

| Metric | Result |
|---|---:|
| Number of blank-image detections | 100,000 |
| Total measured cycles | 295,916,876 cycles |
| Runtime at 50 MHz | ~5.92 seconds |

### One-Line Summary

The final FPGA implementation achieved **100% recognition correctness** with a measured inference latency of only **3,098 cycles**, while successfully validating the design through simulation, synthesis, FPGA board execution, and a 100,000-iteration speed-loop test.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Accelerated Inference Pipeline](#accelerated-inference-pipeline)
- [Optimizations](#optimizations)
- [Measured Results](#measured-results)
- [Tools & Technologies](#tools--technologies)
- [Repository Structure](#repository-structure)
- [How to Run](#how-to-run)
- [Validation](#validation)
- [Notes](#notes)
- [Authors](#authors)

---

## 📖 Overview

This project implements and optimizes a hardware-accelerated Sign Language Recognition system on an FPGA-based K5 / SLRX platform.

The system receives a sign-language image and processes it through a compact neural-network-style inference pipeline:

```text
Input Image → Conv0 → Pool0 → Conv1 → Pool1 → Linear0 → Linear1 → Select / ArgMax
```

The main goal was to reduce inference latency by moving the computationally intensive operations into FPGA accelerators while preserving full functional correctness.

The design was validated using:

- Functional simulation
- Single-iteration cycle-count simulation
- SLRX-level synthesis
- Full FPGA synthesis / fit / STA
- FPGA board programming
- FPGA functional execution
- FPGA performance measurement
- FPGA LST / Speed Loop Test

Main final achievements:

- 100% functional correctness in simulation
- 100% functional correctness on FPGA
- 3,098 FPGA cycles per single inference
- 51.46 MHz achieved at SLRX synthesis level
- 49.82 MHz reported maximum frequency for the full FPGA build
- 295,916,876 cycles for 100,000 blank-image detections in LST mode

---

## 🏗️ Architecture

The project combines software control with hardware acceleration.

The C application running on the K5 CPU configures the accelerator registers, manages input/output buffers, loads model parameters, and controls the inference flow.

The FPGA hardware accelerators execute the computationally intensive stages of the model.

### High-Level System

```text
C Application / K5 CPU
        │
        ▼
Host Registers + Memory Interface
        │
        ▼
SLRX FPGA Accelerators
        │
        ├── Convolution Accelerator
        ├── Max-Pooling Accelerator
        ├── Linear Layer Accelerator
        └── Select / ArgMax Logic
```

### Main Responsibilities

**K5 CPU / C Application**

- Loads model parameters
- Loads input image data
- Configures accelerator registers
- Launches accelerator commands
- Controls the inference pipeline
- Prints classification results and performance data

**SLRX FPGA Accelerators**

- Execute convolution layers
- Execute pooling layers
- Execute fully connected layers
- Reduce execution time of arithmetic-heavy operations
- Provide measured hardware acceleration on the FPGA board

---

## ⚙️ Accelerated Inference Pipeline

### 1. Convolution Layers

The convolution stages, `Conv0` and `Conv1`, apply a 5×5 sliding window over the input image or feature map.

Each output pixel is computed using multiply-accumulate operations:

```text
Output = Saturate(ReLU(sum(pixel × weight) + bias))
```

Each convolution window performs:

- 25 pixel-weight multiplications
- Partial sum accumulation
- Bias addition
- ReLU activation
- Fixed-point descale / normalization
- Saturation to uint8 output format

The convolution stage is one of the most important parts of the accelerator because it performs the largest amount of repeated arithmetic.

---

### 2. Max-Pooling Layers

The pooling stages, `Pool0` and `Pool1`, perform 2×2 max-pooling.

Each 2×2 region is replaced by its maximum value:

```text
[58  92]
[27  14]  →  92
```

Pooling reduces the spatial size of the feature map and lowers the amount of data processed by the next stages.

---

### 3. Linear Layers

The fully connected stages, `Linear0` and `Linear1`, compute vector-matrix operations:

```text
Y = W · X + B
```

Each output neuron is generated by a dot product between the input vector and one row of the weight matrix.

The linear accelerator handles:

- Input vector processing
- Weight vector processing
- Dot-product accumulation
- Bias addition
- Fixed-point scaling and saturation

---

### 4. Select / ArgMax

The final stage selects the class with the highest output score.

The model produces a vector of class scores, and the `Select / ArgMax` stage chooses the index of the maximum value.

For this project, the ArgMax stage was optimized for 27 labels.

---

## 🚀 Optimizations

Several optimizations were applied to improve execution time and timing closure.

### Convolution Datapath Pipelining

The convolution datapath was optimized by splitting the long computation path into smaller stages:

```text
Products → Partial Sums → Total Sum + Bias → ReLU / Saturation → Output Write
```

This reduces the critical path and helps improve the achievable clock frequency.

---

### Reduced Software Overhead

The C application was structured so that setup work is minimized, while the repeated computations are handled by the FPGA accelerators.

This reduces unnecessary CPU-side control overhead and improves the effective inference time.

---

### Optimized ArgMax

The final selection stage was optimized as a direct ArgMax over 27 labels.

This reduces loop overhead and makes the final classification step faster and deterministic.

---

### LST / Speed Loop Test Mode

A special LST mode was added in software to repeatedly execute blank-image inference for 100,000 iterations.

The purpose of this mode is to avoid slow UART image-loading overhead and measure the actual inference logic performance more accurately.

In this mode:

- The input image is blank.
- The model inference is repeated 100,000 times.
- The board 7-segment display shows elapsed time during the run.
- The terminal reports total measured cycles.

---

## 📊 Measured Results

### Functional Results

| Test | Result |
|---|---:|
| Simulation functional success | 100% |
| Simulation detected text | `we are the champions` |
| FPGA functional success | 100% |
| FPGA detected text | `have a great weekend` |

---

### Cycle Count

| Test | Cycles |
|---|---:|
| Simulation single inference | 3,106 cycles |
| FPGA single inference | 3,098 cycles |

---

### Synthesis Results

| Metric | Result |
|---|---:|
| SLRX synthesis logic elements | 15,075 |
| SLRX synthesis achieved clock rate | 51.46 MHz |
| Full FPGA logic elements | 27,045 |
| Full FPGA applied clock target | 50 MHz |
| Full FPGA maximum reported speed | 49.82 MHz |

The difference between the SLRX logic count and the full FPGA logic count is expected.

The SLRX synthesis count includes mainly the accelerator subsystem, while the full FPGA count also includes the K5 SoC infrastructure, UART, memory interfaces, top-level logic, board support logic, and additional FPGA integration logic.

---

### FPGA Per-Layer Cycle Breakdown

| Stage | Cycles |
|---|---:|
| Conv0 | 1,147 |
| Pool0 | 570 |
| Conv1 | 293 |
| Pool1 | 273 |
| Linear0 | 273 |
| Linear1 | 253 |
| Select / ArgMax | 289 |
| **Total** | **3,098** |

---

### LST / Speed Loop Test

| Metric | Result |
|---|---:|
| Number of blank-image detections | 100,000 |
| Total measured cycles | 295,916,876 cycles |
| Runtime at 50 MHz | ~5.92 seconds |

The LST test confirms that the FPGA implementation can repeatedly execute inference logic without being dominated by UART image-loading overhead.

---

## 🛠️ Tools & Technologies

- **SystemVerilog** — FPGA accelerator RTL design
- **C** — Bare-metal application and accelerator drivers
- **K5 / SLRX Platform** — Hardware/software execution framework
- **Quartus Prime** — FPGA synthesis, fitting, timing analysis, and programming
- **Xcelium / K5 Simulation Flow** — Functional simulation
- **Git Bash / Linux Shell** — Build, compile, and execution environment
- **UART** — Application loading and runtime communication
- **USB-Blaster / JTAG** — FPGA programming

---

## 📁 Repository Structure

```text
├── hw/
│   └── xlrs/
│       └── slrx/
│           ├── conv/
│           │   ├── conv.sv
│           │   └── conv.f
│           ├── pool/
│           │   ├── pool.sv
│           │   └── pool.f
│           ├── linear/
│           │   ├── linear.sv
│           │   └── linear.f
│           ├── slrx.sv
│           ├── slrx_def_pkg.sv
│           ├── slrx_enums.svh
│           ├── slrx_regs_intrf.sv
│           └── xmem_intrf_mux.sv
│
├── sw/
│   └── apps/
│       └── slrx/
│           ├── conv.c
│           ├── conv.h
│           ├── pool.c
│           ├── pool.h
│           ├── linear.c
│           ├── linear.h
│           ├── slrx.c
│           ├── slrx.h
│           ├── slrx_cmn.c
│           └── slrx_cmn.h
│
├── results/
│   ├── qsyn_slrx_*.tgz
│   ├── qsyn_fpga_reported.tgz
│   ├── logs/
│   └── screenshots/
│
├── docs/
│   ├── presentation.pptx
│   ├── results_summary.xlsx
│   └── board_demo_images/
│
└── README.md
```

---

## ▶️ How to Run

### 1. Functional Simulation

Open two terminals in the cloud environment.

Terminal 1:

```bash
set_k5_terminal
cd $MY_K5_PROJ/sim
launch_k5_sim slrx
```

Terminal 2:

```bash
set_k5_terminal
cd $MY_K5_PROJ/sim
launch_k5_app slrx -asl $SLR_SHARED -stm -ccd1 ALL_XON
```

Expected result:

```text
DETECTED TEXT: "we are the champions"
Tested 20 images, Passed: 20, Fail: 0, Success: 100.0%
```

---

### 2. Single-Iteration Simulation Performance

```bash
launch_k5_app slrx -asl $SLR_SHARED -stm -ccd1 ALL_XON -itr 1
```

Expected result:

```text
Total: 3,106 cycles
```

---

### 3. SLRX Synthesis

```bash
set_k5_terminal
cd $MY_K5_XLRS/slrx
qsyn_xlr slrx -all | tee qsyn_slrx_all.log
```

Expected key results:

```text
Total FPGA Logic Elements: 15,075
Max FPGA Frequency: 51.46 MHz
```

---

### 4. Full FPGA Build

```bash
set_k5_terminal
cd $MY_K5_PROJ/hw/gen_fpga
comp_fpga slrx -mhz 50 | tee comp_fpga_slrx_50mhz.log
```

Expected key results:

```text
Total FPGA Logic Elements: 27,045
Max FPGA Frequency: 49.82 MHz
FPGA programming file successfully generated
```

Create the FPGA report archive:

```bash
tar -czvf qsyn_fpga_reported.tgz output_files
```

---

### 5. FPGA Programming

On the Windows machine connected to the FPGA board:

```bash
cd /c/k5x_win/k5_xbox_fpga_win
prog_fpga slrx
```

Expected result:

```text
Configuration succeeded
Successfully performed operation(s)
0 errors, 0 warnings
```

---

### 6. FPGA Functional Run

```bash
cd /c/k5x_win/my_k5_proj/run
set_k5_terminal
launch_k5_app slrx -asl $SLR_SHARED -stm -ccd1 ALL_XON
```

Expected result:

```text
DETECTED TEXT: "have a great weekend"
Success: 100%
```

---

### 7. FPGA Single-Iteration Performance

```bash
launch_k5_app slrx -asl $SLR_SHARED -stm -ccd1 ALL_XON -itr 1
```

Expected key result:

```text
Total: 3,098 cycles
```

---

### 8. FPGA LST / Speed Loop Test

```bash
launch_k5_app slrx -asl $SLR_SHARED -stm -ccd1 ALL_XON -ccd2 LST
```

Expected key result:

```text
LST_LOOP: 295,916,876 cycles
Iterations: 100000
Runtime: ~5.92 seconds at 50 MHz
```

---

## ✅ Validation

The project was validated at multiple levels:

| Validation Stage | Status |
|---|---:|
| Functional simulation | Passed |
| Single-iteration simulation | Passed |
| SLRX synthesis | Passed |
| Full FPGA synthesis / fit / STA | Passed |
| FPGA programming | Passed |
| FPGA functional execution | Passed |
| FPGA performance measurement | Passed |
| FPGA LST speed loop | Passed |

Final measured FPGA inference latency:

```text
3,098 cycles / inference
```

At 50 MHz, this corresponds to approximately:

```text
3,098 / 50,000,000 ≈ 61.96 microseconds per inference
```

---

## 📌 Notes

- The `.sof` file contains the synthesized FPGA hardware design.
- C source changes require recompiling the application but do not require regenerating the `.sof`.
- RTL changes require rerunning synthesis and FPGA compilation.
- The SLRX-level synthesis result measures the accelerator subsystem.
- The full FPGA synthesis result includes the accelerator, K5 SoC infrastructure, UART, memory interfaces, top-level FPGA logic, and board-support logic.
- LST mode is implemented in software and is used to measure repeated inference performance without UART image-loading overhead.

---

## 👥 Authors

-Yovel Mentch
-Michael Itskovitch
