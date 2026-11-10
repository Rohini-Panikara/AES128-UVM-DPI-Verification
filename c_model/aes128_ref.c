/* ============================================================
 * aes128_ref.c
 * AES-128 C reference model (FIPS-197), written to mirror the
 * AES_TOP_iterative Verilog design module by module:
 *
 *   C function            Verilog module
 *   -------------------   ---------------------------
 *   sub_bytes()           sub_bytes_comb / sbox
 *   shift_rows()          shift_rows_comb
 *   mix_columns()         mix_column_comb
 *   add_round_key()       "^ round_key_of(round_cnt)"
 *   inv_sub_bytes()       inverse_sub_bytes / inverse_sbox
 *   inv_shift_rows()      inverse_shift_rows_comb
 *   inv_mix_columns()     inverse_mix_column_comb
 *   aes128_key_expansion  key_expasion
 *   aes128_encrypt        encryption_iterative
 *   aes128_decrypt        decryption_iterative
 *
 * State layout: s[0..15], column-major.
 *   s[0..3]  = column 0 = bits [127:96]
 *   s[4..7]  = column 1 = bits [95:64]
 *   s[8..11] = column 2 = bits [63:32]
 *   s[12..15]= column 3 = bits [31:0]
 *   Row r, column c  ->  s[4*c + r]
 * ============================================================ */
#include <stdio.h>
#include <string.h>
#include "aes128_ref.h"

/* ---------------- S-box (sbox.v) ---------------- */
static const uint8_t SBOX[256] = {
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

/* ---------------- Inverse S-box (inverse_sbox.v) ---------------- */
static const uint8_t INV_SBOX[256] = {
  0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
  0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
  0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
  0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
  0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
  0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
  0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
  0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
  0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
  0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
  0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
  0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
  0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
  0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
  0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
  0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d
};

/* Rcon: only the top byte is non-zero (32'h01000000 ... 32'h36000000) */
static const uint8_t RCON[11] = {
  0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
};

/* ---------------- GF(2^8) arithmetic ---------------- */
/* xtime: same as the Verilog function in mix_column_comb.v */
static uint8_t xtime(uint8_t b)
{
    return (uint8_t)((b << 1) ^ ((b & 0x80) ? 0x1b : 0x00));
}

static uint8_t gmul(uint8_t a, uint8_t b)   /* general GF multiply */
{
    uint8_t p = 0;
    while (b) {
        if (b & 1) p ^= a;
        a = xtime(a);
        b >>= 1;
    }
    return p;
}

/* ---------------- Round operations ---------------- */
static void sub_bytes(uint8_t s[16])
{
    for (int i = 0; i < 16; i++) s[i] = SBOX[s[i]];
}

static void inv_sub_bytes(uint8_t s[16])
{
    for (int i = 0; i < 16; i++) s[i] = INV_SBOX[s[i]];
}

/* Row r shifts left by r: new[r][c] = old[r][(c+r)%4] */
static void shift_rows(uint8_t s[16])
{
    uint8_t t[16];
    for (int c = 0; c < 4; c++)
        for (int r = 0; r < 4; r++)
            t[4*c + r] = s[4*((c + r) % 4) + r];
    memcpy(s, t, 16);
}

/* Row r shifts right by r: new[r][c] = old[r][(c-r+4)%4] */
static void inv_shift_rows(uint8_t s[16])
{
    uint8_t t[16];
    for (int c = 0; c < 4; c++)
        for (int r = 0; r < 4; r++)
            t[4*c + r] = s[4*((c - r + 4) % 4) + r];
    memcpy(s, t, 16);
}

/* Matrix {02 03 01 01} - same equations as mix_column_comb.v */
static void mix_columns(uint8_t s[16])
{
    for (int c = 0; c < 4; c++) {
        uint8_t *col = &s[4*c];
        uint8_t a0 = col[0], a1 = col[1], a2 = col[2], a3 = col[3];
        col[0] = gmul(a0,2) ^ gmul(a1,3) ^ a2          ^ a3;
        col[1] = a0          ^ gmul(a1,2) ^ gmul(a2,3) ^ a3;
        col[2] = a0          ^ a1          ^ gmul(a2,2) ^ gmul(a3,3);
        col[3] = gmul(a0,3) ^ a1          ^ a2          ^ gmul(a3,2);
    }
}

/* Matrix {0e 0b 0d 09} - same equations as inverse_mix_column_comb.v */
static void inv_mix_columns(uint8_t s[16])
{
    for (int c = 0; c < 4; c++) {
        uint8_t *col = &s[4*c];
        uint8_t a0 = col[0], a1 = col[1], a2 = col[2], a3 = col[3];
        col[0] = gmul(a0,14) ^ gmul(a1,11) ^ gmul(a2,13) ^ gmul(a3,9);
        col[1] = gmul(a0,9)  ^ gmul(a1,14) ^ gmul(a2,11) ^ gmul(a3,13);
        col[2] = gmul(a0,13) ^ gmul(a1,9)  ^ gmul(a2,14) ^ gmul(a3,11);
        col[3] = gmul(a0,11) ^ gmul(a1,13) ^ gmul(a2,9)  ^ gmul(a3,14);
    }
}

static void add_round_key(uint8_t s[16], const uint8_t rk[16])
{
    for (int i = 0; i < 16; i++) s[i] ^= rk[i];
}

/* ---------------- Key expansion (key_expasion.v) ----------------
 * w[i] = 4-byte word. w0..w3 = key.
 * w[i] = w[i-4] ^ g(w[i-1], i/4)   if i % 4 == 0
 * w[i] = w[i-4] ^ w[i-1]           otherwise
 * g() = RotWord -> SubWord -> XOR Rcon  (g_func in Verilog)
 * ----------------------------------------------------------------- */
void aes128_key_expansion(const uint8_t key[16], uint8_t round_keys[11][16])
{
    uint8_t w[44][4];

    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            w[i][j] = key[4*i + j];

    for (int i = 4; i < 44; i++) {
        uint8_t t[4];
        memcpy(t, w[i-1], 4);

        if (i % 4 == 0) {
            uint8_t tmp = t[0];              /* RotWord (rotate left 1 byte) */
            t[0] = t[1]; t[1] = t[2]; t[2] = t[3]; t[3] = tmp;
            for (int j = 0; j < 4; j++)      /* SubWord */
                t[j] = SBOX[t[j]];
            t[0] ^= RCON[i / 4];             /* XOR Rcon (top byte only) */
        }
        for (int j = 0; j < 4; j++)
            w[i][j] = w[i-4][j] ^ t[j];
    }

    for (int r = 0; r < 11; r++)             /* o_key_s0 .. o_key_s10 */
        for (int i = 0; i < 4; i++)
            memcpy(&round_keys[r][4*i], w[4*r + i], 4);
}

/* ---------------- Encryption core ---------------- */
static void encrypt_core(const uint8_t key[16], const uint8_t pt[16],
                         uint8_t ct[16], int trace)
{
    uint8_t rk[11][16], s[16];
    char hex[33];

    aes128_key_expansion(key, rk);
    memcpy(s, pt, 16);

    /* S_IDLE: state_reg <= i_Plain_Text ^ round_key0 */
    add_round_key(s, rk[0]);
    if (trace) { aes128_bytes_to_hex(s, hex); printf("  %-36s: %s\n", "Round  0 (AddRoundKey with key 0)", hex); }

    /* S_ROUND: round_cnt = 1..10 */
    for (int round = 1; round <= 10; round++) {
        sub_bytes(s);
        shift_rows(s);
        if (round != 10)                 /* final round skips MixColumns */
            mix_columns(s);
        add_round_key(s, rk[round]);
        if (trace) { aes128_bytes_to_hex(s, hex); { char lbl[40]; sprintf(lbl, "Round %2d", round); printf("  %-36s: %s\n", lbl, hex); }; }
    }
    memcpy(ct, s, 16);
}

void aes128_encrypt(const uint8_t key[16], const uint8_t pt[16], uint8_t ct[16])
{
    encrypt_core(key, pt, ct, 0);
}

void aes128_encrypt_trace(const uint8_t key[16], const uint8_t pt[16], uint8_t ct[16])
{
    encrypt_core(key, pt, ct, 1);
}

/* ---------------- Decryption core (decryption_iterative.v) ----------------
 * Initial: state = ct ^ rk[10]
 * For key_idx = 9 .. 0:
 *     InvShiftRows -> InvSubBytes -> AddRoundKey(rk[key_idx])
 *     -> InvMixColumns (skipped when key_idx == 0)
 * -------------------------------------------------------------------------- */
static void decrypt_core(const uint8_t key[16], const uint8_t ct[16],
                         uint8_t pt[16], int trace)
{
    uint8_t rk[11][16], s[16];
    char hex[33];

    aes128_key_expansion(key, rk);
    memcpy(s, ct, 16);

    /* S_IDLE: state_reg <= i_Cipher_Text ^ round_key10 */
    add_round_key(s, rk[10]);
    if (trace) { aes128_bytes_to_hex(s, hex); printf("  %-36s: %s\n", "Round  0 (AddRoundKey with key 10)", hex); }

    /* S_ROUND: key_idx = 9 .. 0  ->  decryption rounds 1 .. 10 */
    for (int key_idx = 9; key_idx >= 0; key_idx--) {
        inv_shift_rows(s);
        inv_sub_bytes(s);
        add_round_key(s, rk[key_idx]);
        if (key_idx != 0)                /* final round skips InvMixColumns */
            inv_mix_columns(s);
        if (trace) { aes128_bytes_to_hex(s, hex); { char lbl[40]; sprintf(lbl, "Round %2d (uses key %d)", 10 - key_idx, key_idx); printf("  %-36s: %s\n", lbl, hex); }; }
    }
    memcpy(pt, s, 16);
}

void aes128_decrypt(const uint8_t key[16], const uint8_t ct[16], uint8_t pt[16])
{
    decrypt_core(key, ct, pt, 0);
}

void aes128_decrypt_trace(const uint8_t key[16], const uint8_t ct[16], uint8_t pt[16])
{
    decrypt_core(key, ct, pt, 1);
}

/* ---------------- Hex helpers ---------------- */
static int hexval(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

int aes128_hex_to_bytes(const char *hex, uint8_t out[16])
{
    for (int i = 0; i < 16; i++) {
        int hi = hexval(hex[2*i]), lo = hexval(hex[2*i + 1]);
        if (hi < 0 || lo < 0) return -1;
        out[i] = (uint8_t)((hi << 4) | lo);
    }
    return 0;
}

void aes128_bytes_to_hex(const uint8_t in[16], char out[33])
{
    for (int i = 0; i < 16; i++) sprintf(&out[2*i], "%02x", in[i]);
    out[32] = '\0';
}
