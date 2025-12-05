# 🔒 FPGA-Based AES-128 Encryption Core

![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)
![Hardware](https://img.shields.io/badge/Hardware-Nexys%20A7%20%7C%20Artix--7-orange.svg)
![Interface](https://img.shields.io/badge/Interface-UART-green.svg)

## 📖 Overview
This repository contains a Register-Transfer Level (RTL) implementation of the **Advanced Encryption Standard (AES-128)** algorithm. The design is capable of performing 128-bit encryption on hardware and features a **UART-based input/output wrapper**, allowing users to interact with the encryption core via a standard serial terminal (e.g., PuTTY, Tera Term).

The project is designed for Xilinx FPGAs (specifically targeting the Artix-7/Nexys A7 architecture with a 100MHz clock) but is synthesizable for other platforms.

## ✨ Key Features
* **Standard Compliance:** Implements the FIPS 197 AES standard with a 128-bit key size.
* **Hardware Accelerator:** Dedicated hardware datapath for high-speed encryption (SubBytes, ShiftRows, MixColumns, AddRoundKey).
* **UART Bridge:** Includes a custom UART TX/RX module for sending plaintext and receiving ciphertext over USB-UART.
* **Finite State Machine (FSM):** Robust control logic managing key expansion and the 10-round encryption process.
* **ASCII-to-Hex Conversion:** On-chip logic converts incoming ASCII characters to hexadecimal values for processing.

---

## 🏗️ Architecture
The system consists of the following high-level modules:

1.  **`top_uart_aes.sv`**: The top-level wrapper. It synchronizes UART signals, buffers incoming ASCII data into 128-bit blocks, controls the AES core, and serializes the result back to the host.
2.  **`aes128_core.sv`**: The main encryption engine. It manages the state matrix and coordinates the round transformations.
3.  **`aes128_key_expand.sv`**: Generates the 11 round keys required for the encryption process on the fly.
4.  **`uart_rx.sv` / `uart_tx.sv`**: Handles physical layer serial communication.

### Data Flow
1.  **Input:** User types 32 Hex characters (representing 128 bits) into a terminal.
2.  **Buffering:** The FPGA receives ASCII bytes, converts them to Nibbles, and packs them into a 128-bit `plaintext` register.
3.  **Processing:** Once a full block is received, the FSM triggers the AES Core.
4.  **Output:** The 128-bit `ciphertext` is unpacked into nibbles, converted back to ASCII, and transmitted back to the terminal.

---

## 📂 File Structure

| Filename | Description |
| :--- | :--- |
| **`top_uart_aes.sv`** | Top-level module connecting UART IO to the AES Core. |
| **`aes.sv`** | The AES Core containing the main datapath and state machine. |
| **`aes128_key_expand.sv`** | Performs the Key Schedule (RotWord, SubWord, Rcon). |
| **`s-box.sv`** | 256-entry Substitution Box (Lookup Table). |
| **`sub_byte.sv`** | Applies S-Box substitution to the 128-bit state. |
| **`shiftrows.sv`** | Cyclically shifts bytes in the state rows. |
| **`mixcolumns.sv`** | Matrix multiplication over Galois Field GF(2^8). |
| **`uart_rx.sv`** | UART Receiver (Deserializer). |
| **`uart_tx.sv`** | UART Transmitter (Serializer). |

---

## ⚙️ Hardware Implementation Details

### Clock & Timing
* **System Clock:** 100 MHz
* **Baud Rate:** 115200 (Configured via `CLKS_PER_BIT` parameter = 868).

### Encryption Key
For this demonstration, the 128-bit encryption key is hardcoded in `top_uart_aes.sv`:
```systemverilog
// Key: 0x000102030405060708090A0B0C0D0E0F
localparam logic [127:0] AES_KEY = 128'h000102030405060708090A0B0C0D0E0F;