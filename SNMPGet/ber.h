/*
 * Copyright (c) 2017 Dariusz Stojaczyk. All Rights Reserved.
 * The following source code is released under an MIT-style license,
 * that can be found in the LICENSE file.
 */

#ifndef BER_H
#define BER_H

#include <stdint.h>

/** ASN.1 primitives */
enum ber_data_type {
    BER_DATA_T_INTEGER = 0x02,
    BER_DATA_T_OCTET_STRING = 0x04,
    BER_DATA_T_NULL = 0x05,
};

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Encode variable-length unsigned 32-bit integer.
 * Note that this function does not check against output buffer overflow.
 * It will write at most 5 bytes.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @param num number to encode in any expected endianness
 * @return pointer to the next empty byte in the given buffer.
 * Will always be smaller than given buf pointer.
 */
uint8_t *ber_encode_vlint(uint8_t *out, uint32_t num);

/**
 * Decode variable-length unsigned 32-bit integer.
 * Note that this function does not check against input buffer overflow.
 * It will read at most 5 bytes.
 * @param buf pointer to the **beginning** of the input buffer.
 * The first byte will be decoded from buf, next one from (buf + 1), etc.
 * @param num pointer to put decoded number into. It's previous value will
 * be overwritten. In case this function returns NULL, the content of num
 * is undefined.
 * @return pointer to the next not processed byte in the given buffer or
 * NULL in case decoded vlint consists of more than 5 bytes.
 */
uint8_t *ber_decode_vlint(uint8_t *buf, uint32_t *num);

/**
 * Encode integer in BER.
 * Note that this function is does not check against output buffer overflow.
 * It will write at most 6 bytes.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @param num number to encode in any expected endianness
 * @return pointer to the next empty byte in the given buffer.
 * Will always be smaller than given buf param.
 */
uint8_t *ber_encode_int(uint8_t *out, uint32_t num);

/**
 * Decode BER integer.
 * Note that this function does not check against input buffer overflow.
 * It will read at most 6 bytes.
 * @param buf pointer to the **beginning** of the input buffer.
 * The first byte should be BER_DATA_T_INTEGER. However, this function
 * does not check against it.
 * @param num pointer to put decoded number into. It's previous value will
 * be overwritten. In case this function returns NULL, the content of num
 * is undefined.
 * @return pointer to the next not processed byte in the given buffer or
 * NULL in case if integer length is bigger than 4 bytes.
 */
uint8_t *ber_decode_int(uint8_t *buf, uint32_t *num);

/**
 * Encode BER length.
 * For use with user-defined types.
 * BER uses special format of encoding length.
 * It can be either short or long form.
 * For example, encoding length = 1 can be done as following:
 * * Short form: length = 0x01
 * * Long form: length = 0x81 0x01
 * Short form is straightforward, it's applicable on lengths < 128.
 * For long form, the first byte has a special meaning:
 *  * MSB must be 1
 *  * The rest of the bits form a number of subsequent bytes used
 *    to encode actual length.
 * This function will use short form when length < 128, long form otherwise.
 * Note that this function is does not check against output buffer overflow.
 * It will write at most 5 bytes.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @param length length to encode in any expected endianness
 * @return pointer to the next empty byte in the given buffer.
 * Will always be smaller than given buf param.
 */
uint8_t *ber_encode_length(uint8_t *out, uint32_t length);

/**
 * Decode BER length.
 * @see See ber_encode_length for details on BER length.
 * Note that this function does not check against input buffer overflow.
 * It will read at most 5 bytes.
 * @param buf pointer to the **beginning** of the input buffer.
 * The first byte will be decoded from buf, next one from (buf + 1), etc.
 * @param length pointer to put decoded length into. It's previous value will
 * be overwritten. In case this function returns NULL, the content of length
 * is undefined.
 * @return pointer to the next not processed byte in the given buffer or
 * NULL in case decoded length consists of more than 5 bytes.
 */
uint8_t *ber_decode_length(uint8_t *buf, uint32_t *length);

/**
 * Encode octet string in BER.
 * Note that this function is does not check against output buffer overflow.
 * It will write at most 6+strlen(str) bytes.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @param str string to encode (pointer to the **first** char)
 * @param str_len length of given string
 * @return pointer to the next empty byte in the given buffer.
 * Will always be smaller than given buf param.
 */
uint8_t *ber_encode_string_len(uint8_t *out, char *str, uint32_t str_len);

/**
 * Encode octet string in BER.
 * Note that this function is does not check against output buffer overflow.
 * It will write at most 6+strlen(str) bytes.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @param str NUL-terminated string to encode (pointer to the **first** char)
 * @return pointer to the next empty byte in the given buffer.
 * Will always be smaller than given buf param.
 */
uint8_t *ber_encode_string(uint8_t *out, char *str);

/**
 * Decode BER octet string. This function gets length and beginning of
 * the string directly from the input buffer.
 * Note that this function does not check against input buffer overflow!
 * It will read at most 6 bytes. 7th byte is beginning of the string,
 * but it won't be dereferenced.
 * @param buf pointer to the **beginning** of the input buffer.
 * The first byte should be BER_DATA_T_OCTET_STRING. However, this function
 * does not check against it.
 * @param str pointer to the decoded string. This function will set *str to
 * point to the beginning of the string taken directly from buf.
 * The string is char*, but when the buffer changes, so will this string.
 * If this function returns NULL, the contents of *str* is undefined.
 * @param str_len pointer where decoded strength will be written. If this
 * function returns NULL, the contents of *str_len* is undefined.
 * @return pointer to the next not processed byte in the given buffer or
 * NULL in case decoded string length is invalid.
 */
uint8_t *ber_decode_string_len_buffer(uint8_t *buf, char **str, uint32_t *str_len);

/**
 * Decode BER octet string.
 * This function will modify input buffer!
 * Future processing of the same buffer might not be possible.
 * @param buf pointer to the **beginning** of the input buffer.
 * The first byte should be BER_DATA_T_OCTET_STRING. However, this function
 * does not check against it. The buffer has to be at least 7 + *maxlen*
 * bytes big.
 * @param str pointer to the decoded string. This function will
 * set *str to point to the beginning of the string taken directly from buf.
 * The byte just after the string will be zero'ed, so that *str* is
 * NULL-terminated. The previous value of this byte is returned via *next*
 * param. The string is char*, but when the buffer changes, so will
 * this string. If this function returns NULL, the contents of *str*
 * is undefined.
 * @param maxlen max length of decoded string. If decoded length exceeds
 * this value, the function will return NULL.
 * @return pointer to the just-zero'ed byte in the given buffer or NULL
 * in case decoded string length is invalid. The decoding functions do not
 * check BER type, so that returned buf can be easily decoded further.
 */
uint8_t *ber_decode_string_buffer(uint8_t *buf, char **str, uint32_t maxlen);

///**
// * Decode BER octet string.
// * @param buf pointer to the **beginning** of the input buffer.
// * The first byte should be BER_DATA_T_OCTET_STRING. However, this function
// * does not check against it. The buffer has to be at least 6 + *maxlen*
// * bytes big.
// * @param str pointer to the decoded string. It will be allocated and set
// * by this function. If this function returns NULL, the *str* won't be
// * allocated.
// * @param maxlen max length of decoded string. If decoded length exceeds
// * this value, the function will return NULL.
// * @return pointer to the next not processed byte in the given buffer or
// * NULL in case decoded string length is invalid or malloc() failed.
// */
//uint8_t *ber_decode_string_alloc(uint8_t *buf, char **str, uint32_t maxlen);

/**
 * Encode NULL in BER.
 * Note that this function is does not check against output buffer overflow.
 * It will write exactly 2 bytes.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @return pointer to the next empty byte in the given buffer.
 * Will always be smaller than given buf param.
 */
uint8_t *ber_encode_null(uint8_t *out);

/**
 * Decode BER NULL.
 * Note that this function is does not check against output buffer overflow.
 * It will read exactly 2 bytes.
 * @param buf pointer to the **beginning** of the input buffer.
 * @return pointer to the next not processed byte in the given buffer.
 */
uint8_t *ber_decode_null(uint8_t *buf);

#if 0 // untested and unused
/**
 * Encode data in BER using fprintf-like syntax.
 * Note that this function does not check against output buffer overflow.
 * @param out pointer to the **end** of the output buffer.
 * The first encoded byte will be put in buf, next one in (buf - 1), etc.
 * @param fmt c printf-like format string. It supports only format specifiers.
 * Any detected non format specifier will cause to return with NULL.
 * @param ... c printf-like parameters specified in fmt field
 * @return pointer to the first byte of encoded sequence in given buffer or NULL
 * if fmt parsing error occured.
 */
uint8_t *ber_fprintf(uint8_t *out, char *fmt, ...);

/**
 * Decode BER data using sscanf-like syntax.
 * Note that this function does not check against input buffer overflow.
 * @param buf pointer to the **beginning** of the input buffer.
 * The first byte will be decoded from buf, next one from (buf + 1), etc.
 * @param fmt c printf-like format string. It supports only format specifiers.
 * Any detected non format specifier will cause to return with NULL.
 * Currently supported:
 *  * %u - integer
 *  * %n - null
 *  * %ms or %as - dynamically allocated string
 * @param ... c printf-like parameters specified in fmt field
 * @return pointer to the first byte of encoded sequence in given buffer or NULL
 * if fmt parsing error occured.
 */
uint8_t *ber_sscanf(uint8_t *buf, char *fmt, ...);
#endif

#ifdef __cplusplus
}
#endif

#endif //BER_H

