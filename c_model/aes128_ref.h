/* ============================================================
 * aes128_ref.h
 * AES-128 C reference model for the AES_TOP_iterative RTL.
 *
 * Byte ordering matches the Verilog exactly:
 *   byte[0]  <-> bits [127:120]
 *   byte[1]  <-> bits [119:112]
 *   ...
 *   byte[15] <-> bits [7:0]
 * i.e. the 128-bit hex value 128'h0011..ff is the byte array
 * {0x00, 0x11, ..., 0xff}. State is column-major (FIPS-197),
 * same as s0..s15 in mix_column_comb.v.
 * ============================================================ */
#ifndef AES128_REF_H
#define AES128_REF_H

#include <stdint.h>

/* 11 round keys x 16 bytes = key_expasion o_key_s0 .. o_key_s10 */
void aes128_key_expansion(const uint8_t key[16], uint8_t round_keys[11][16]);

/* Same behaviour as encryption_iterative.v */
void aes128_encrypt(const uint8_t key[16], const uint8_t pt[16], uint8_t ct[16]);

/* Same behaviour as decryption_iterative.v */
void aes128_decrypt(const uint8_t key[16], const uint8_t ct[16], uint8_t pt[16]);

/* Same as encrypt, but prints state after every round.
 * Compare these values with state_reg in the waveform when debugging. */
void aes128_encrypt_trace(const uint8_t key[16], const uint8_t pt[16], uint8_t ct[16]);

/* Same as decrypt, but prints state after every decryption round. */
void aes128_decrypt_trace(const uint8_t key[16], const uint8_t ct[16], uint8_t pt[16]);

/* Helpers: hex string (32 chars) <-> 16-byte array */
int  aes128_hex_to_bytes(const char *hex, uint8_t out[16]);
void aes128_bytes_to_hex(const uint8_t in[16], char out[33]);

#endif
