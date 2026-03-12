def frodo_sample(z_16bit: int) -> int:
    """
    使用 16-bit 随机数 z_16bit 进行一次 FrodoKEM 错误采样。
    返回 8-bit 的错误值（以补码形式表示）。
    """
    # 你的 CDT 表 (FrodoKEM-1344)
    CDT = [9142, 23462, 30338, 32361, 32725, 32765, 32767]
    
    # 提取高 15 位作为概率值 (prnd)，提取最低 1 位作为符号位 (sign)
    prnd = z_16bit >> 1
    sign = z_16bit & 1
    
    # 初始化错误值
    e = 0
    
    # 恒定时间 (Constant-time) 比较逻辑：
    # 如果生成的随机概率大于等于 CDT 表中的阈值，错误值就加 1
    for t in CDT:
        if prnd >= t:
            e += 1
            
    # 应用符号位：如果 sign 为 1，则取相反数
    if sign == 1:
        e = -e
        
    # 转换为 8-bit 的结果 (处理 Python 中的负数补码表示)
    return e & 0xFF

def sample_64bit_to_4x8bit(input_64bit: int) -> list[int]:
    """
    将 64-bit 输入拆分为 4 个 16-bit 块，分别采样出 4 个 8-bit 数据。
    """
    samples_8bit = []
    
    # 将 64 位数据分为 4 个 16 位的片段 (从小端/低位开始提取)
    for i in range(4):
        # 通过位移和掩码提取 16 bit
        z = (input_64bit >> (16 * i)) & 0xFFFF
        
        # 传入采样函数
        e_8bit = frodo_sample(z)
        samples_8bit.append(e_8bit)
        
    return samples_8bit

# ==========================================
# 测试代码
# ==========================================
if __name__ == "__main__":
    # 假设我们有一个 64 位的随机输入 (十六进制表示)
    # 拆分来看: 
    # 块3: 0x8A1F (35359) -> prnd=17679, sign=1 
    # 块2: 0x0001 (1)     -> prnd=0, sign=1
    # 块1: 0x5BEE (23534) -> prnd=11767, sign=0
    # 块0: 0x4756 (18262) -> prnd=9131, sign=0
    test_input_64 = 9081892455026383941
    
    print(f"64位输入数据: {hex(test_input_64)}")
    
    # 执行采样
    results = sample_64bit_to_4x8bit(test_input_64)
    
    # 打印结果
    print("\n采样出的 4 个 8 位数据 (十进制 / 十六进制):")
    for i, res in enumerate(results):
        # 还原负数用于直观展示，如果是十六进制 > 127 则是负数
        signed_val = res if res < 128 else res - 256
        print(f"Sample {i}: 十进制 {signed_val:>2}  /  十六进制 0x{res:02X}")