-- 防刷限流: 禁止高频率访问的ip; 每个接口每秒至多处理10个请求
local function close_redis(red)
    if not red then
        return
    end
    --释放连接(连接池实现)
    local pool_max_idle_time = 10000 --毫秒
    local pool_size = 100 --连接池大小
    local ok, err = red:set_keepalive(pool_max_idle_time, pool_size)

    if not ok then
        ngx_log(ngx_ERR, "set redis keepalive error : ", err)
    end
end

-- 等待
local function wait()
    -- 睡眠
   ngx.sleep(1)
end


local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(1000)

-- ip
local ip = "127.0.0.1"
-- 端口
local port = 6379
-- 连接
local ok, err = red:connect(ip,port)
-- 密码认证(没有的可以不用)
-- red:auth("*******");
-- 选择库
red:select(20);
if not ok then
    return close_redis(red)
end

local uri = ngx.var.uri -- 获取当前请求的uri
local uriKey = "req:uri:"..uri

-- ngx.req.get_headers: 获取头信息
-- ngx.var.remote_addr: 获取真实ip
local clientIP = ngx.req.get_headers()["X-Real-IP"]
if clientIP == nil then
   clientIP = ngx.req.get_headers()["x_forwarded_for"]
end
if clientIP == nil then
   clientIP = ngx.var.remote_addr
end

local incrKey = "user:"..clientIP..":freq"
local blockKey = "user:"..clientIP..":block"

-- 检测阻塞值
local is_block,err = red:get(blockKey) -- check if ip is blocked
if tonumber(is_block) == 1 then
   -- 结束请求并跳转到403
   -- ngx.print("请求频率过高,请稍后重试!");
   -- ngx.exit(ngx.HTTP_FORBIDDEN)
   ngx.exit(403)
   return close_redis(red)
end


-- 自增, 没有就初始化为0在自增
res, err = red:incr(incrKey)
if res == 1 then
   -- 设置自增键过期时间
   expire_res, err = red:expire(incrKey,1)
end

if res > 200 then
    -- 设置阻塞
    res, err = red:set(blockKey,1)
    -- expire: 设置阻塞过期时间
    res, err = red:expire(blockKey,600)
end


-- 根据uri记录请求次数
--[[
-- 自增
local res, err = redis.call('incr',KEYS[1])
if res == 1 then
    local resexpire, err = redis.call('expire',KEYS[1],KEYS[2])
end
return (res)
]]--
-- red:incr("test1");
res, err = red:eval("local res, err = redis.call('incr',KEYS[1]) if res == 1 then local resexpire, err = redis.call('expire',KEYS[1],KEYS[2]) end return (res)",2,uriKey,1)
-- 超过10次等待处理请求
while (res > 10)
do
   -- red:incr("test");
   -- ngx.thread.spawn: 再生协程
   local twait, err = ngx.thread.spawn(wait)
   -- ngx.thread.wait: 等待协程终止才结束请求
   ok, threadres = ngx.thread.wait(twait)
   if not ok then
      ngx_log(ngx_ERR, "wait sleep error: ", err)
      break;
   end
   --[[
    local res, err = redis.call('incr',KEYS[1])
    if res == 1 then
        local resexpire, err = redis.call('expire',KEYS[1],KEYS[2])
    end
    return (res)
    ]]--
   res, err = red:eval("local res, err = redis.call('incr',KEYS[1]) if res == 1 then local resexpire, err = redis.call('expire',KEYS[1],KEYS[2]) end return (res)",2,uriKey,1)
end
close_redis(red)