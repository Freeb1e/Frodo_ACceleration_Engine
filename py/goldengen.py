import numpy as np
import os

# --- 1. 定义矩阵维度 ---
# 根据 ref_matrix_*.bin 文件大小推导:
# ref_matrix_A.bin: 3612672 bytes / 2 (uint16) = 1806336 = 1344 * 1344
# ref_matrix_ST_8bit.bin: 10752 bytes / 1 (int8) = 10752 = 8 * 1344
# ref_matrix_E.bin: 21504 bytes / 2 (uint16) = 10752 = 1344 * 8
ROWS_A = 1344
COMMON_DIM = 1344
COLS_S = 8

# --- 2. 定义数据类型 (DTypes) ---
DTYPE_A = np.uint16
DTYPE_S = np.int8
DTYPE_E = np.uint16
DTYPE_C = np.uint16

print(f"--- FrodoKEM AS & ASE 仿真数据生成器 ---")
print(f"配置维度:")
print(f"  A 矩阵: ({ROWS_A}, {COMMON_DIM}) [类型: {DTYPE_A.__name__}]")
print(f"  S 矩阵: ({COMMON_DIM}, {COLS_S}) [类型: {DTYPE_S.__name__}]")
print(f"  E 矩阵: ({ROWS_A}, {COLS_S})    [类型: {DTYPE_E.__name__}]")
print("-" * 50)

# --- 3. 加载测试数据 ---
file_A_in = 'ref_matrix_A.bin'
file_ST_in = 'ref_matrix_ST_8bit.bin'
file_E_in = 'ref_matrix_E.bin'

if not all(os.path.exists(f) for f in [file_A_in, file_ST_in, file_E_in]):
    print("❌ 错误: 找不到输入文件 ref_matrix_A.bin, ref_matrix_ST_8bit.bin 或 ref_matrix_E.bin")
    exit(1)

# 加载 A
A = np.fromfile(file_A_in, dtype=DTYPE_A).reshape((ROWS_A, COMMON_DIM))
# 加载 S^T 并转置得到 S
ST = np.fromfile(file_ST_in, dtype=DTYPE_S).reshape((COLS_S, COMMON_DIM))
S = ST.T
# 加载 E
E = np.fromfile(file_E_in, dtype=DTYPE_E).reshape((ROWS_A, COLS_S))

print("✅ 成功加载 A, S 和 E 测试数据。")

# --- 4. 计算 AS ---
# 使用 int64 进行中间计算以防止溢出，并处理有符号 S
A_64 = A.astype(np.int64)
S_64 = S.astype(np.int64)

AS_full = np.dot(A_64, S_64)
AS_result = (AS_full % (2**16)).astype(DTYPE_C)

# --- 5. 计算 AS + E ---
ASE_full = AS_full + E.astype(np.int64)
ASE_result = (ASE_full % (2**16)).astype(DTYPE_C)

print("\n--- 计算完成 ---")
print(f"AS_result.shape:  {AS_result.shape}")
print(f"ASE_result.shape: {ASE_result.shape}")
print("-" * 50)

# --- 6. 保存结果到 .bin 文件 ---
file_AS = 'AS.bin'
file_ASE = 'ASE.bin'

AS_result.tofile(file_AS)
ASE_result.tofile(file_ASE)

print(f"✅ 结果已保存为二进制文件:")
print(f"  -> {file_AS} ({os.path.getsize(file_AS)} bytes)")
print(f"  -> {file_ASE} ({os.path.getsize(file_ASE)} bytes)")

# --- 7. 保存结果到 .txt 文件 (人类阅读) ---
file_AS_txt = 'AS.txt'
file_ASE_txt = 'ASE.txt'

np.savetxt(file_AS_txt, AS_result[:8, :], fmt='%6d', delimiter=' ', 
           header=f'AS Result (First 8 rows of {ROWS_A}x{COLS_S})')
np.savetxt(file_ASE_txt, ASE_result[:8, :], fmt='%6d', delimiter=' ', 
           header=f'ASE Result (First 8 rows of {ROWS_A}x{COLS_S})')

print(f"\n✅ 已生成部分数据的文本预览:")
print(f"  -> {file_AS_txt}")
print(f"  -> {file_ASE_txt}")
print("-" * 50)
print("任务完成。")