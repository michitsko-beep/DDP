import numpy as np
import random

# --------------------------------------------------------------------------------------
# Little endian / hex helpers
def uint32_ltlend_hex_str(val):
    val &= 0xFFFFFFFF
    bigend_hex_str = '%08x' % val
    return '%s %s %s %s ' % (
        bigend_hex_str[6:8],
        bigend_hex_str[4:6],
        bigend_hex_str[2:4],
        bigend_hex_str[0:2]
    )

def int8_hex_str(val):
    # הבטחת ייצוג hex תקין לערכי signed int8
    val = int(val) & 0xFF
    return '%02x' % val

# --------------------------------------------------------------------------------------
# K5 / XMEM configuration
XBOX_TCM_BASE_ADDR = 0x40000000
XMEM_SIZE = 2 * 1024 * 32  # 64K Bytes [cite: 48, 255]
MAX_N = 256

# --------------------------------------------------------------------------------------
# Generate FFT-CONV configuration
n = 256 # גודל קבוע להשוואה
mode = 1 # 2 = השוואה בין שתי השיטות (Naive vs FFT)

# יישור ל-32 בתים עבור ביצועי XMEM אופטימליים [cite: 128, 517]
def align_to_32(addr):
    return (addr + 31) & ~31

# חישוב כתובות מיושרות לכל וקטור
total_vector_size = n  # n bytes for each int8 vector
base_ofst = align_to_32(random.randint(0, XMEM_SIZE - (3 * align_to_32(n))))

c_addr = XBOX_TCM_BASE_ADDR + base_ofst
x_addr = c_addr + align_to_32(n)
y_addr = x_addr + align_to_32(n)

# --------------------------------------------------------------------------------------
# כתיבת קובץ הקונפיגורציה
with open('fft_test_config.txt', 'w') as config_file:
    config_file.write('# K5-XBOX FFT Config - 32-byte aligned\n\n')
    config_file.write('%s # c_addr = %08x\n' % (uint32_ltlend_hex_str(c_addr), c_addr))
    config_file.write('%s # x_addr = %08x\n' % (uint32_ltlend_hex_str(x_addr), x_addr))
    config_file.write('%s # y_addr = %08x\n' % (uint32_ltlend_hex_str(y_addr), y_addr))
    config_file.write('%s # n = %08x (%d decimal)\n' % (uint32_ltlend_hex_str(n), n, n))
    config_file.write('%s # mode = %08x (%d decimal)\n' % (uint32_ltlend_hex_str(mode), mode, mode))

# --------------------------------------------------------------------------------------
# יצירת וקטורים אקראיים (Signed int8)
c_vec = np.random.randint(-128, 128, size=n, dtype=np.int16)
x_vec = np.random.randint(-128, 128, size=n, dtype=np.int16)

with open('fft_test_in.txt', 'w') as test_in_file:
    test_in_file.write('# FFT input data: c followed by x\n\n')
    
    # כתיבה בפורמט של 32 בתים בשורה להתאמה ויזואלית ל-XMEM [cite: 260]
    num_bytes_per_line = 32
    all_bytes = list(c_vec) + list(x_vec)

    for i, v in enumerate(all_bytes):
        test_in_file.write(int8_hex_str(v))
        if (i + 1) % num_bytes_per_line == 0:
            test_in_file.write('\n')
        else:
            test_in_file.write(' ')

print(f'Generated files with 32-byte alignment.')
print(f'N={n}, Mode={mode}')
print(f'Addresses: C:0x{c_addr:08x}, X:0x{x_addr:08x}, Y:0x{y_addr:08x}')