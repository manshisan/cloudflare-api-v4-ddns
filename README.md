# Cloudflare API v4 DDNS 使用说明

## 概述

这是一个基于 Cloudflare API v4 的动态DNS (DDNS) 脚本，能够自动更新您的 Cloudflare DNS 记录以匹配当前的公网IP地址。适用于需要动态更新域名解析的场景，如家庭服务器、远程访问等。

## 功能特性

- 自动检测当前公网IP地址（支持IPv4和IPv6）
- 智能比较IP变化，只在IP改变时更新DNS记录
- 支持强制更新模式
- 自动缓存Zone ID和Record ID，提高执行效率
- 详细的错误处理和日志输出
- （可选）将更新状态通知tg

## 前置要求

### 1. 系统要求
- Linux/Unix 系统（支持bash）
- 已安装 `curl` 命令
- 网络连接正常

### 2. Cloudflare账户准备
1. 登录 [Cloudflare控制台](https://dash.cloudflare.com/)
2. 确保您的域名已添加到Cloudflare并处于活动状态
3. 获取API Token：
   - 进入 "My Profile" → "API Tokens"
   - 创建自定义Token或使用Global API Key
   - 确保Token具有Zone:Read和DNS:Edit权限

## 安装步骤

### 1. 下载脚本
```bash
curl https://raw.githubusercontent.com/manshisan/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh > /usr/local/bin/cf-v4-ddns.sh
chmod +x /usr/local/bin/cf-v4-ddns.sh
```

### 2. 配置脚本
有两种配置方式：

#### 方式一：直接编辑脚本文件
编辑 `cf-v4-ddns.sh` 文件，修改以下变量：
```bash
# API密钥
CFKEY="your-cloudflare-api-key"

# 用户邮箱
CFUSER="user@example.com"

# 域名
CFZONE_NAME="example.com"

# 要更新的主机名
CFRECORD_NAME="host.example.com"

# 记录类型 (A为IPv4, AAAA为IPv6)
CFRECORD_TYPE=A

# TTL值 (120-86400秒)
CFTTL=120

# tg bot的token
TG_BOT_TOKEN="your-telegram-bot-token"

# tg chat id
TG_CHAT_ID="your-telegram-chat-id"
```

#### 方式二：使用命令行参数
无需修改脚本，直接通过参数传递配置。

## 使用方法

### 基本用法
```bash
/usr/local/bin/cf-v4-ddns.sh -k your-api-key -u user@example.com -h host.example.com -z example.com -b your-telegram-bot-token -c your-telegram-chat-id 
```

### 完整参数说明

#### 必需参数
- `-k` : Cloudflare API密钥
- `-u` : Cloudflare账户邮箱
- `-h` : 要更新的主机名（完整域名）
- `-z` : Zone名称（根域名）

#### 可选参数
- `-t` : 记录类型
  - `A` : IPv4地址（默认）
  - `AAAA` : IPv6地址
- `-f` : 强制更新模式
  - `false` : 仅在IP变化时更新（默认）
  - `true` : 无论IP是否变化都强制更新
- `-b` : telegram的bot token
- `-c` : telegram的chat id

### 使用示例

#### 1. 更新IPv4记录
```bash
/usr/local/bin/cf-v4-ddns.sh -k "your-api-key" -u "user@example.com" -h "home.example.com" -z "example.com" -t A
```

#### 2. 更新IPv6记录
```bash
/usr/local/bin/cf-v4-ddns.sh -k "your-api-key" -u "user@example.com" -h "home.example.com" -z "example.com" -t AAAA
```

#### 3. 强制更新（忽略IP比较）
```bash
/usr/local/bin/cf-v4-ddns.sh -k "your-api-key" -u "user@example.com" -h "home.example.com" -z "example.com" -f true
```

#### 4. 子域名自动补全
如果您只提供子域名，脚本会自动补全：
```bash
# 输入: -h "home" -z "example.com"
# 自动补全为: home.example.com
/usr/local/bin/cf-v4-ddns.sh -k "your-api-key" -u "user@example.com" -h "home" -z "example.com"
```
#### 5. 同步成功通知tg
```bash
/usr/local/bin/cf-v4-ddns.sh -k "your-api-key" -u "user@example.com" -h "home.example.com" -z "example.com" -b your-telegram-bot-token -c your-telegram-chat-id 
```
## 自动化运行

### 设置定时任务（推荐）

使用crontab设置定时执行：

```bash
# 编辑crontab
crontab -e

# 每分钟执行一次（无日志）
*/1 * * * * /usr/local/bin/cf-v4-ddns.sh >/dev/null 2>&1

# 每5分钟执行一次（记录日志）
*/5 * * * * /usr/local/bin/cf-v4-ddns.sh >> /var/log/cf-v4-ddns.log 2>&1

# 每小时执行一次
0 * * * * /usr/local/bin/cf-v4-ddns.sh >> /var/log/cf-v4-ddns.log 2>&1
```

### 系统服务方式
如果您希望以系统服务的方式运行，可以创建systemd服务或init脚本。

## 文件说明

脚本运行时会在用户home目录创建以下文件：

### 1. IP缓存文件
- 文件位置：`$HOME/.cf-wan_ip_[记录名].txt`
- 作用：保存上次的公网IP，用于比较是否发生变化
- 示例：`.cf-wan_ip_home.example.com.txt`

### 2. ID缓存文件
- 文件位置：`$HOME/.cf-id_[记录名].txt`
- 作用：缓存Zone ID和Record ID，避免重复API调用
- 内容格式：
  ```
  zone_id
  record_id
  zone_name
  record_name
  ```

## 故障排除

### 常见错误及解决方案

#### 1. "Missing api-key" 错误
- **原因**：未提供API密钥
- **解决**：确保通过 `-k` 参数提供有效的API密钥

#### 2. "Missing username" 错误
- **原因**：未提供用户邮箱
- **解决**：通过 `-u` 参数提供Cloudflare账户邮箱

#### 3. "Missing hostname" 错误
- **原因**：未指定要更新的主机名
- **解决**：通过 `-h` 参数提供完整的主机名

#### 4. "Could not get zone ID" 错误
- **原因**：无法获取域名的Zone ID
- **解决**：
  - 检查域名是否正确添加到Cloudflare
  - 验证API密钥权限
  - 确认域名拼写无误

#### 5. "Could not get record ID" 错误
- **原因**：DNS记录不存在
- **解决**：
  - 在Cloudflare控制台手动创建对应的DNS记录
  - 检查记录名称是否正确

#### 6. IP地址检测失败
- **原因**：无法访问外部IP检测服务
- **解决**：
  - 检查网络连接
  - 可能需要配置代理

### 调试技巧

#### 1. 启用详细输出
在脚本中取消注释以下行来查看API响应：
```bash
echo "Zone API response: $ZONE_RESPONSE"
echo "Record API response: $RECORD_RESPONSE"
```

#### 2. 手动测试API调用
```bash
# 测试Zone API
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=example.com" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json"
```

#### 3. 检查缓存文件
```bash
# 查看IP缓存
cat ~/.cf-wan_ip_*.txt

# 查看ID缓存
cat ~/.cf-id_*.txt
```

## 安全注意事项

1. **API密钥保护**：妥善保管您的Cloudflare API密钥，不要在公共场所或代码仓库中暴露
2. **文件权限**：确保脚本文件和缓存文件的权限设置合理
3. **日志安全**：如果记录日志，注意日志文件的权限和轮转
4. **最小权限原则**：API Token应仅授予必要的权限（Zone:Read, DNS:Edit）

## 高级配置

### 1. 自定义IP检测源
修改脚本中的 `WANIPSITE` 变量：
```bash
# IPv4
WANIPSITE="http://ipv4.icanhazip.com"
# 或者
WANIPSITE="https://api.ipify.org/"

# IPv6
WANIPSITE="http://ipv6.icanhazip.com"
```

### 2. 自定义TTL值
根据需要调整DNS记录的TTL（生存时间）：
```bash
CFTTL=300  # 5分钟
CFTTL=3600 # 1小时
```

### 3. 多记录管理
为不同的记录创建不同的脚本副本或配置文件。

## 版本信息

- 当前版本基于Cloudflare API v4
- 支持Bearer Token认证方式
- 兼容IPv4和IPv6
- 添加了telegram bot通知

## 许可证

请参考[原项目](https://github.com/yulewang/cloudflare-api-v4-ddns)的许可证声明。

## 支持与反馈

如遇问题或需要帮助，请：
1. 检查本使用说明的故障排除部分
2. 查看脚本的详细输出
3. 访问原项目GitHub页面获取最新信息

---
*AI生成*
*最后更新：2025年8月27日*
