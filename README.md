## 防刷限流

- 防刷功能：一秒内访问次数过高将会被封禁一段时间

- 限流功能：超过限流次数将会等待处理请求

### 在Openresty中的使用方法

打开脚本`openresty_limit.lua`配置`redis`
```
# IP
local ip = "127.0.0.1"
# 端口
local port = 6379
# 密码
red:auth("*****");
# 选择存储库
red:select(0);
```

`openresty`中加载脚本
```
server {
    listen  80 default;
    listen 443 ssl;
    server_name *.xxxxxx.com;
    root /usr/share/nginx/html/;
    # 加载lua脚本，路径根据自己情况定
    access_by_lua_file /etc/nginx/lua/openresty_limit.lua;
}
```

如何动态防刷限流：以下两个配置是从redis读取，如果没有则使用默认值，所以只要通过程序动态修改以下两个值即可
```
limit_max_num: 每秒最高访问次数,默认200
limit_flow_num: 每秒最高处理请求数，默认10
```