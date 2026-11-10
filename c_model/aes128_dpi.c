/* ============================================================
 * aes128_dpi.c
 * DPI-C wrappers so the UVM scoreboard can call the C model
 * directly during simulation (no file dumping).
 *
 * SystemVerilog side (put in the scoreboard or a package):
 *
 *   import "DPI-C" function void dpi_aes128_encrypt(
 *       input  bit [127:0] key,
 *       input  bit [127:0] pt,
 *       output bit [127:0] ct);
 *
 *   import "DPI-C" function void dpi_aes128_decrypt(
 *       input  bit [127:0] key,
 *       input  bit [127:0] ct,
 *       output bit [127:0] pt);
 *
 * A bit[127:0] arrives in C as svBitVecVal[4] (32-bit words):
 *   word[0] = bits [31:0]   ...   word[3] = bits [127:96]
 * The helpers below convert that to the model's byte order
 * (byte[0] = bits [127:120]).
 * ============================================================ */
#include "svdpi.h"
#include "aes128_ref.h"

static void sv_to_bytes(const svBitVecVal *v, uint8_t b[16])
{
    for (int i = 0; i < 16; i++) {
        int bit_lsb = 8 * (15 - i);               /* byte i = bits [bit_lsb+7 : bit_lsb] */
        b[i] = (uint8_t)(v[bit_lsb / 32] >> (bit_lsb % 32));
    }
}

static void bytes_to_sv(const uint8_t b[16], svBitVecVal *v)
{
    for (int w = 0; w < 4; w++) v[w] = 0;
    for (int i = 0; i < 16; i++) {
        int bit_lsb = 8 * (15 - i);
        v[bit_lsb / 32] |= ((svBitVecVal)b[i]) << (bit_lsb % 32);
    }
}

void dpi_aes128_encrypt(const svBitVecVal *key, const svBitVecVal *pt, svBitVecVal *ct)
{
    uint8_t k[16], p[16], c[16];
    sv_to_bytes(key, k);
    sv_to_bytes(pt, p);
    aes128_encrypt(k, p, c);
    bytes_to_sv(c, ct);
}

void dpi_aes128_decrypt(const svBitVecVal *key, const svBitVecVal *ct, svBitVecVal *pt)
{
    uint8_t k[16], c[16], p[16];
    sv_to_bytes(key, k);
    sv_to_bytes(ct, c);
    aes128_decrypt(k, c, p);
    bytes_to_sv(p, pt);
}
