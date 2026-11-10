/* ============================================================
 * test_aes128.c
 * Standalone test of the C reference model (no simulator needed).
 *
 * 1. Known-answer tests from FIPS-197 / NIST SP 800-38A
 *    -> proves the C model itself is correct.
 * 2. Encrypt -> decrypt round trip on random vectors.
 * 3. Round-by-round trace for the vector used in AES_TB_iterative.v
 *    -> compare with state_reg in the waveform.
 *
 * Build:  gcc -O2 -Wall -o test_aes128 aes128_ref.c test_aes128.c
 * Run:    ./test_aes128
 * ============================================================ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "aes128_ref.h"

typedef struct { const char *name, *key, *pt, *ct; } kat_t;

static const kat_t KATS[] = {
    { "FIPS-197 Appendix B",
      "2b7e151628aed2a6abf7158809cf4f3c",
      "3243f6a8885a308d313198a2e0370734",
      "3925841d02dc09fbdc118597196a0b32" },
    { "FIPS-197 Appendix C.1",
      "000102030405060708090a0b0c0d0e0f",
      "00112233445566778899aabbccddeeff",
      "69c4e0d86a7b0430d8cdb78070b4c55a" },
    { "SP 800-38A F.1.1 block 1",
      "2b7e151628aed2a6abf7158809cf4f3c",
      "6bc1bee22e409f96e93d7e117393172a",
      "3ad77bb40d7a3660a89ecaf32466ef97" },
    { "SP 800-38A F.1.1 block 2",
      "2b7e151628aed2a6abf7158809cf4f3c",
      "ae2d8a571e03ac9c9eb76fac45af8e51",
      "f5d3d58503b9699de785895a96fdbaaf" },
    { "SP 800-38A F.1.1 block 3",
      "2b7e151628aed2a6abf7158809cf4f3c",
      "30c81c46a35ce411e5fbc1191a0a52ef",
      "43b1cd7f598ece23881b00e3ed030688" },
    { "SP 800-38A F.1.1 block 4",
      "2b7e151628aed2a6abf7158809cf4f3c",
      "f69f2445df4f9b17ad2b417be66c3710",
      "7b0c785e27e8ad3f8223207104725dd4" }, 
};

int main(void)
{
    int fails = 0;
    char hex[33];
    uint8_t key[16], pt[16], ct[16], exp_ct[16], back[16];

    /* ---------- 1. Known-answer tests ---------- */
    printf("=== Known-answer tests ===\n");
    for (size_t i = 0; i < sizeof(KATS)/sizeof(KATS[0]); i++) {
        aes128_hex_to_bytes(KATS[i].key, key);
        aes128_hex_to_bytes(KATS[i].pt,  pt);
        aes128_hex_to_bytes(KATS[i].ct,  exp_ct);

        aes128_encrypt(key, pt, ct);
        aes128_decrypt(key, ct, back);

        int ok_enc = (memcmp(ct, exp_ct, 16) == 0);
        int ok_dec = (memcmp(back, pt, 16) == 0);
        aes128_bytes_to_hex(ct, hex);
        printf("%-26s enc=%s  %s | dec %s\n", KATS[i].name, hex,
               ok_enc ? "PASS" : "FAIL", ok_dec ? "PASS" : "FAIL");
        fails += !ok_enc + !ok_dec;
    }

    /* ---------- 2. Random round-trip ---------- */
    printf("\n=== Random round-trip (10000 vectors) ===\n");
    srand(12345);
    int rt_fail = 0;
    for (int n = 0; n < 10000; n++) {
        for (int i = 0; i < 16; i++) { key[i] = rand() & 0xff; pt[i] = rand() & 0xff; }
        aes128_encrypt(key, pt, ct);
        aes128_decrypt(key, ct, back);
        if (memcmp(back, pt, 16) != 0) rt_fail++;
    }
    printf("round-trip failures: %d\n", rt_fail);
    fails += rt_fail;

    /* ---------- 3. Round-by-round trace (AES_TB_iterative.v vector) ---------- */
    const char *TB_KEY = "5468617473206D79204B756E67204675";
   const char *TB_PT  = "29C3505F571420F6402299B31A02D73A"; 
   
   
    aes128_hex_to_bytes(TB_KEY, key);
    aes128_hex_to_bytes(TB_PT,  pt);

    printf("\n==================================================================\n");
    printf("                        AES-128 ENCRYPTION\n");
    printf("==================================================================\n");
    aes128_bytes_to_hex(pt, hex);  printf("  %-36s: %s\n", "Plain Text", hex);
    aes128_bytes_to_hex(key, hex); printf("  %-36s: %s\n", "Key", hex);
    printf("  ----------------------------------------------------------------\n");
    aes128_encrypt_trace(key, pt, ct);
    printf("  ----------------------------------------------------------------\n");
    aes128_bytes_to_hex(ct, hex);  printf("  %-36s: %s\n", "Cipher Text", hex);

    printf("\n==================================================================\n");
    printf("                        AES-128 DECRYPTION\n");
    printf("==================================================================\n");
    aes128_bytes_to_hex(ct, hex);  printf("  %-36s: %s\n", "Cipher Text", hex);
    aes128_bytes_to_hex(key, hex); printf("  %-36s: %s\n", "Key", hex);
    printf("  ----------------------------------------------------------------\n");
    aes128_decrypt_trace(key, ct, back);
    printf("  ----------------------------------------------------------------\n");
    aes128_bytes_to_hex(back, hex); printf("  %-36s: %s\n", "Recovered Plain Text", hex);
    printf("  %-36s: %s\n", "Match with original plain text", memcmp(back, pt, 16) == 0 ? "YES" : "NO");
    if (memcmp(back, pt, 16) != 0) fails++;

    printf("\n%s (%d failures)\n", fails ? "OVERALL: FAIL" : "OVERALL: PASS", fails);
    return fails ? 1 : 0;
}
