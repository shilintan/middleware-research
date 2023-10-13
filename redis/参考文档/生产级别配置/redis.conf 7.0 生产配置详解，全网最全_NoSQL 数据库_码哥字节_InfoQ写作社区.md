# redis.conf 7.0 生产配置详解，全网最全

作者：码哥字节

- 2023-01-12

  广东

- 本文字数：19422 字

  阅读完需：约 64 分钟

![redis.conf 7.0 生产配置详解，全网最全](./redis.conf 7.0 生产配置详解，全网最全_NoSQL 数据库_码哥字节_InfoQ写作社区.assets/3f91747e5d6e894ba680bbb35213aaeb.webp)

# 我是码哥，可以叫我靓仔，关注公众号解锁更多硬核

我是 Redis， 当程序员用指令 `./redis-server /path/to/redis.conf` 把我启动的时候，第一个参数必须是`redis.conf` 文件的路径。



这个文件很重要，就好像是你们的 DNA，它能控制我的运行情况，不同的配置会有不同的特性和人生，它掌握我的人生命运，控制着我如何完成高可用、高性能。合理的配置能让我更快、更省内存，并发挥我最大的优势让我更安全运行。



以下这些配置大家必知必会，需要大家掌握每个配置背后的技术原理，学会融合贯通并在生产中正确配置，解决问题。避免出现技术悬浮，原理说的叭叭叭，配置像个大傻瓜。



本文配置文件版本是 Redis 7.0。

## 常规通用配置

这些是我的常规配置，每个 Redis 启动必备参数，你一定要掌握，涉及到网络、模块插件、运行模式、日志等。

### MODULES

这个配置可以加载模块插件增强我的功能，常见的模块有 RedisSearch、RedisBloom 等。关于模块加载可以参考【5.6 布隆过滤器原理与实战】章节集成布隆过滤器便是通过以下配置实现加载布隆过滤器插件。



```shell
loadmodule /opt/app/RedisBloom-2.2.14/redisbloom.so
```

复制代码

### NETWORK

这部分都是与网络相关的配置，很重要滴，配置不当将会有安全和性能问题。

#### bind

`bind`用于绑定**本机的网络接口**（网卡），注意是本机。



每台机器可能有多个网卡，每个网卡都有一个 IP 地址。配置了 bind，则表示我只允许来自本机指定网卡的 Redis 请求。



> MySQL：“bind 是用于限制访问你的机器 IP 么？”



非也，**注意，这个配置指的并不是只有 bind 指定的 IP 地址的计算机才能访问我。**如果想限制指定的主机连接我，只能通过防火墙来控制，bind 参数不也能起到这个作用。



举个例子：如果我所在的服务器有两个网卡，每个网卡有一个 IP 地址， IP1，IP2。



配置 `bind IP1`，则表示只能通过这个网卡地址来的网络请求访问我，也可以使用空格分割绑定多个网卡 IP。



我的默认配置是`bind 127.0.0.1 -::1` 表示绑定本地回环地址 IPv4 和 Ipv6。- 表示当 ip 不存在也能启动成功。

#### protected-mode

> MySQL：网络世界很危险滴，你如何保证安全？



默认开启保护模式，如果没有设置密码或者没有 bind 配置，我**只允许在本机连接我，其它机器无法连接**。



如果想让其它机器连接我，有以下三种方式。



1. 配置为 `protected-mode no`（不建议，地球很危险滴，防人之心不可无）。
2. `protected-mode yes`，配置 bind 绑定本机的 IP。
3. `protected-mode yes`，除了设置 `bind` 以外，还可以通过 `requirepass magebyte`设置密码为 `magebyte`， 让其他机器的客户端能使用密码访问我。



**bind、protected-mode、requirepass 之间的关系**



- bind：指定的是我所在服务器网卡的 IP，**不是指定某个可以访问我的机器。**
- protected-mode：保护模式，默认开启，如果没有设置密码或者 bind IP，我只接受本机访问(没密码+保护模式启动=本地访问)。
- requirepass，Redis 客户端连接我通行的密码。



如果参数设置为`bind 127.0.0.1 -::1`，不管 `protected-mode`是否开启，只能本机用 127.0.0.1 连接，其他外机无法连接。



**在生产环境中，为了安全，不要关闭 protected-mode，并设置** `**requirepass**` **参数配置密码和 bind 绑定机器的网卡 IP。**

#### port 6379

用于指定我监听的客户端 socket 端口号，默认 6379。设置为 0 则不会监听 TCP 连接，我想没人设置为 0 吧。

#### tcp-backlog 511

用于在 `Linux` 系统中控制 TCP 三次握手**已完成连接队列**（完成三次握手后）的长度，如果已完成连接队列已经满则无法放入，客户端会报`read timeout`或者`connection reset by peer`的错。



> MySQL：“在高并发系统中这玩意需要调大些吧？”



是的，我的默认配置是 511，这个配置的值不能大于 Linux 系统定义的 /proc/sys/net/core/somaxconn 值，Linux 默认的是 128。



所以我在启动的时候你会看到这样的警告：`WARNING: The TCP backlog setting of 511 cannot be enforced because kern.ipc.somaxconn is set to the lower value of 128.`



当系统并发量大并且客户端速度缓慢的时候，在高并发系统中，需要设置一个较高的值来避免客户端连接速度慢的问题。



需要分别调整 Linux 和 Redis 的配置。



**建议修改为 2048 或者更大**，Linux 则在 `/etc/sysctl.conf`中添加`net.core.somaxconn = 2048`配置，并且在终端执行 `sysctl -p`即可。



码哥使用 macOS 系统，使用 `sudo sysctl -w kern.ipc.somaxconn=2048`即可。

#### timeout

`timeout 60` 单位是秒，如果在 timout 时间内客户端跟我没有数据交互（客户端不再向我发送任何数据），我将关闭该客户端连接。



**注意事项**



- 0 表示永不断开。
- timeout 对应源码 `server.maxidletime`

#### tcp-keepalive

`tcp-keepalive 300` 单位是秒，官方建议值是 300。这是一个很有用的配置，实现 TCP 连接复用。



**用途**



用于客户端与服务端的长连接，如果设置为非 0，则使用 `SO_KEEPALIVE` 周期性发送 ACK 给客户端，俗话就是**用来定时向客户端发送 tcp_ack 包来探测客户端是否存活，并保持该连接**。不用每次请求都建立 TCP 连接，毕竟创建连接是比较慢的。

### 常规配置

这些都是我的常规配置，比较通用，你必须了解。你可以把这些配置写到一个特有文件中，其他节点可以使用 `include /path/to/other.conf` 配置来加载并复用该配置文件的配置。

#### daemonize

配置`daemonize yes`表示使用守护进程的模式运行，默认情况下我是以非守护线程的模式运行（daemonize no），开启守护进程模式，会生成一个 `.pid`文件存储进程号。



你也可以配置 `pidfile /var/run/redis_6379.pid` 参数来指定文件的生成目录，当关闭服务的时候我会自动删除该文件。

#### loglevel

指定我在运行时的日志记录级别。默认是 `loglevel notice`。有以下几个选项可以配置。



- debug：会记录很多信息，主要用于开发和测试。
- verbose：许多用处不大的信息，但是比 debug 少，如果发现生产出现一些问题无从下手，可使用该级别来辅助定位。
- notice：生产一般配置这个级别。
- warning：只会记录非常重要/关键的的日志。

#### logfile

指定日志文件目录，默认是 `logfile ""`，表示只在标准控制台输出。



**需要注意的是，如果使用标准控制台输出，并且使用守护进程的模式运行，日志会发送到 /dev/null。**

#### databases

设置数据库数量，我的默认配置是 `databases 16` 。默认的数据库是 `DB 0`，使用集群模式的时候， database 只有一个，就是 `DB 0`。

## RDB 快照持久化

> MySQL：“要怎么开启 RDB 内存快照文件实现持久化呢？”



RDB 快照持久化相关的配置，必须掌握，合理配置能我实现宕机快速恢复实现高可用。

### save

使用 `save <seconds> <changes>` 开启持久化，比如 `save 60 100` 表示 60 秒内，至少执行了 100 个写操作，则执行 RDB 内存快照保存。



不关心是否丢失数据，你也可以通过配置 `save ""` 来禁用 RDB 快照保存，让我性能起飞，冲出三界外。



默认情况的我会按照如下规则来保存 RDB 内存快照。



- 在 3600 秒 (一个小时) 内，至少执行了一次更改。
- 在 300 秒(5 分钟)内，至少执行了 100 个更改。
- 在 60 秒后，至少执行了 10000 个更改。



也可以通过 `save 3600 1 300 100 60 10000` 配置来显示设置。

### stop-writes-on-bgsave-error

> MySQL：“bgsave 失败的话，停止接收写请求要怎么配置？”



默认配置为 `stop-writes-on-bgsave-error yes`，它的作用是**如果 RDB 内存快照持久化开启并且最后一次** `**bgsave**` **失败的话就停止接收写请求。**



我通过这种强硬的方式来告知程序员数据持久化不正常了，否则可能没人知道 RDB 快照持久化出问题了。



当 `bgsave` 后台进程能正常工作，我会自动允许写请求。如果你对此已经有相关的监控，即使磁盘出问题（磁盘空间不足、没有权限等）的情况下依旧处理写请求，那么设置成 `no` 即可。

### rdbcompression

> MySQL：“RDB 内存快照文件比较大，可以压缩么？”



我的默认配置是 `rdbcompression yes`，意味着**对 RDB 内存快照文件中的 String 对象使用 LZF 算法做压缩**。这个非常有用，能大大减少文件大小，受益匪浅呀，建议你开启。



如果你不想损失因为压缩 RDB 内存快照文件的 CPU 资源，那就设置成 `no`，带来的后果就是文件比较大，传输占用更大的带宽（要三思啊，老伙计）。

### rdbchecksum

默认配置是 `rdbchecksum yes`，从 5.0 版本开始，RDB 文件末尾会写入一个 CRC64 检验码，能起到一定的纠错作用，但是要**丢失大约 10%** 的性能损失，你可以设置成功 `no` 关闭这个功能来获得更快的性能。



关闭了这个功能， RDB 内存快照文件的校验就是 0 ，代码会自动跳过检查。



**推荐你关闭，让我快到令人发指。**



你还可以通过 `dbfilename` 参数来指定 RDB 内存快照文件名，默认是 `dbfilename dump.rdb`。

### rdb-del-sync-files

默认配置是 `rdb-del-sync-files no`，主从进行全量同步时，通过传输 RDB 内存快照文件实现，没有开启 RDB 持久化的实例在同步完成后会删除该文件，通常情况下保持默认即可。

### dir

我的工作目录，注意这是目录而不是文件， 默认配置是`dir ./`。比如存放 RDB 内存快照文件、AOF 文件。

## 主从复制

这部分配置很重要，涉及到主从复制的方方面面，是高可用的基石，重点对待啊伙计们。

### replicaof

**主从复制，使用**`**replicaof <masterip> <masterport>**` **配置将当前实例成为其他 Redis 服务的从节点**。



- masterip，就是 master 的 IP。
- masterport，master 的端口。



有以下几点需要注意。



- 我使用异步实现主从复制，当 Master 节点的 slave 节点数量小于指定的数量时，你可以设置 Master 节点停止处理写请求。
- 主从复制如果断开的时间较短，slave 节点可以执行部分重新同步，需要合理设置 `backlog size`，保证这个缓存区能完整保存断连期间 Master 接受写请求的数据，防止出现全量复制，具体配置后面会细说。
- 主从复制是自动的，不需要用户干预。

### masterauth

如果当前节点是 slave，且 master 节点配置了 `requirepass` 参数设置了密码，那么 slave 节点必须使用该参数配置为 master 的密码，否则 master 节点将拒绝该 slave 节点的请求。



配置方式为 `masterauth <master-password>`。

### masteruser

在 6.0 以上版本，如果使用了我的 ACL 安全功能，只配置 `masterauth` 还不够。因为默认用户不能运行 `PSYNC` 命令或者主从复制所需要的其他命令。



这时候，最好配置一个专门用于主从复制的特殊用户，配置方式为 `masteruser <username>`。

### replica-serve-stale-data

> MySQL：“当 slave 节点与 master 失去连接，导致主从同步失败的时候，还能处理客户端请求么？”



slave 节点可以有以下两种行为来决定是否处理客户端请求。



- 配置为 `yes`，slave 节点可以继续处理客户端请求，但是数据可能是旧的，因为新的没同步过来。也可能是空的，如果是第一次同步的话。
- 配置为 `no`，slave 节点将返回错误 `MASTERDOWN Link with MASTER is down and replica-serve-stale-data is set to no`给客户端。但是以下的指令还是可以执行：`INFO, REPLICAOF, AUTH, SHUTDOWN, REPLCONF, ROLE, CONFIG, SUBSCRIBE,UNSUBSCRIBE, PSUBSCRIBE, PUNSUBSCRIBE, PUBLISH, PUBSUB, COMMAND, POST,HOST and LATENCY`。



我的默认配置是 `replica-serve-stale-data yes`。

### replica-read-only

这个配置用于控制 slave 实例能否接收写指令，在 2.6 版本后默认配置为 `yes`，表示 slave 节点只处理读请求，如果为 `no` 则可读可写。



**我建议保持默认配置，让 slave 节点只作为副本实现高可用。想要提高写性能，使用集群模式横向拓展更好。**

### repl-diskless-sync

主从复制过程中，新加入的 slave 节点和 slave 节点重连后无法进行增量同步，需要进行一次全量同步，master 节点会生成 RDB 内存快照文件传输给 slave 节点。



所以这个配置是用于控制传输方式的，传输方式有两种。



- Disk-backed（磁盘备份）：master 节点创建新进程将 RDB 内存快照文件写到磁盘，主进程逐步将这个文件传输到不同 slave 节点。
- Diskless（无盘备份）：master 节点创建一个新进程直接把 RDB 内存快照内容写到 Socket，不会将 RDB 内存快照文件持久化到磁盘。



使用磁盘备份的方式，master 保存在磁盘的 RDB 内存快照文件可以让多个 slave 复用。



使用无盘备份的话，当 RDB 内存快照文件传输开始，如果当前有多个`slave` 节点与 master 建立连接，我会使用并行传输的方式将 RDB 内容传输给多个节点。



**默认的配置是 `repl-diskless-sync yes`，表示使用无盘备份。在磁盘速度很慢，而网络超快的情况下，无盘备份会更给力。**如果网络很慢，有可能会出现数据丢失，推荐你改成 no。

### repl-diskless-sync-delay

使用无盘复制的话，**如果此刻有新的 slave 发起全量同步，需要等待之前的传输完毕才能开启传输。**



所以可以使用配置 `repl-diskless-sync-delay 5` 参数指定一个延迟时间，这个单位是秒，让 master 节点等待一会，让更多 slave 节点连接再执行传输。



**因为一旦开始传输，master 节点无法响应新的 slave 节点的全量复制请求，只能在队列中等待下一次 RDB 内存快照传输。**



想要关闭这个功能，设置为 0 即可。

### repl-diskless-load

mastar 节点有两种方式传输 RDB，slave 节点也有两种方式加载 master 传输过来的 RDB 数据。



- 传统方式：接受到数据后，先持久化到磁盘，再从磁盘加载 RDB 文件恢复数据到内存中，这是传统方式。
- diskless-load：从 Socket 中一边接受数据，一边解析，实现无盘化。



一共有三个取值可配置。



- disabled：不使用 diskless-load 方式，即采用磁盘化的传统方式。
- on-empty-db：安全模式下使用 diskless-load（也就 slave 节点数据库为空的时候使用 diskless-load）。
- swapdb：使用 diskless-load 方式加载，slave 节点会缓存一份当前数据库的数据，再清空数据库，接着进行 Socket 读取实现加载。缓存一份数据的目的是防止读取 Socket 失败。



**需要注意的是，diskless-load 目前在实验阶段，因为 RDB 内存快照数据并没有持久化到磁盘，因此有可能造成数据丢失；**



**另外，该模式会占用更多内存，可能会导致 OOM。**

### repl-ping-replica-period

默认配置`repl-ping-replica-period 10` 表示 slave 每 10 秒 PING 一次 master。

### repl-timeout

很重要的一个参数，slave 与 master 之间的复制超时时间，默认配置是`repl-timeout 60`，表示在 60 秒内 ping 不通，则判定超时。



超时包含以下三种情况。



- slave 角度，全量同步期间，在 repl-timeout 时间内没有收到 master 传输的 RDB 内存快照文件。
- slave 角度，在 repl-timeout 时间内没有收到 master 发送的数据包或者 ping。
- master 角度，在 repl-timeout 时间内没有收到 REPCONF ACK （复制偏移量 offset）确认信息。



当检测到超时，将会关闭 master 与 slave 之间的连接，slave 会发起重新建立主从连接的请求，对于内存数据比较大的系统，可以增大 `repl-timeout` 的值。



你需要注意的是，这个配置一定要大于 `repl-ping-replica-period`的值，否则每次心跳监测都超时。

### repl-disable-tcp-nodelay

当 slave 与 master 全量同步（slave 发送 psync/sync 指令给 master）完成后，后续的增量同步是否设置成 `TCP_NODELAY`。



如果设置成 `yes`，master 将合并小的 TCP 包从而节省带宽，但是会增加同步延迟（40 ms），造成 master 与 slave 数据不一致；设置成 `no`，则 master 会立即发送数据给 slave，没有延迟。



默认配置 `repl-disable-tcp-nodelay no`。

### repl-backlog-size

设置主从复制积压缓冲区（backlog） 容量大小，**这是一个环形数组，正常主从同步不涉及到 repl-backlog。当主从断开重连，repl-backlog 的作用就出来了**。



缓冲区用于存放断连期间 master 接受的写请求数据，当主从断开重连，通常不需要执行全量同步，只需要将断连期间的部分数据传递到 slave 即可。



**主从复制积压缓冲区越大，slave 可以承受的断连时间越长。**



默认配置是 `repl-backlog-size 1mb`，建议根据每秒流量大小和断开重连时间长，设置大一点，比如 128 mb。

### repl-backlog-ttl

用于配置当 master 与 slave 断连多少秒之后，master 清空主从复制积压缓冲区（repl-backlog）。配置成 0 ，表示永远不清空。默认配置`repl-backlog-ttl 3600`。

### replica-priority

slave 优先级，这个配置是给哨兵使用的，当 master 节点挂掉，哨兵会选择一个 priority 最小的 slave 节点作为新的 master，这个值越小没接越优先选中。



如果是 0，那意味着这个 slave 将不能选中成为 master，默认配置是 `replica-priority 100`。

### min-slaves-to-write 和 min-slaves-max-lag

这两个配置要一起设置才有意义，如果有一个配置成 0，表示关闭该特性。



先看默认配置含义。



```shell
min-replicas-to-write 3min-replicas-max-lag 10
```

复制代码



如果 master 发现超过 3 个 slave 节点连接 master 延迟大于 10 秒，那么 master 就停止接收客户端写请求。**这么做的目的是为了尽可能保证主从数据一致性。**



master 会记录每个 slave 最近一次发来 ping 的时间，掌握每个 slave 的运行情况。

### tracking-table-max-keys

我在 Redis 6.0 版本，实现了服务端辅助实现客户端缓存的特性，需要追踪客户端有哪些 key。当某个 key 被修改，我需要把这个失效信息发送到对应的客户端将本地缓存失效，这个配置就是用于指定追踪表保存的最大 key 数量，一旦超过这个数量，即使这个 key 没有被修改，为了回收内存我也会强制这个 key 所在的客户端缓存值失效。



设置 0 表示不限制，需要注意的是，如果使用广播模式实现键追踪，则不需要额外内存，忽略这个配置。



使用广播模式的不足就是与这个 key 无关的客户端也会收到失效消息。

## 安全

正是由于我快的一塌糊涂，攻击者一秒钟可以尝试 100 万个密码，所以你应该使用非常健壮的密码。

### ACL

ACL 日志的最大长度，默认配置 `acllog-max-len 128` 表示最大 128 mb。



另外，使用 `aclfile /etc/redis/users.acl` 配置 ACL 文件所在位置。

### requirepass

当前 Redis 服务器的访问密码，默认是不需要密码访问，网络危险，必须设置，如 `requirepass magebyte660`设置密码为 “magebyte666”。

### maxclients

设置客户端同时连接的最大数量，默认设置是 `maxclients 10000`。达到最大值，我将关闭客户端新的连接，并发送一个 `max number of clients reached` 错误给客户端。

## 内存管理

作为用内存保存数据的我，这部分的配置也相当重要。

### maxmemory

设置使用内存最大字节，当内存达到限制，我将尝试根据配置的内存淘汰策略（参见 maxmemory-policy）删除一些 key。建议你不要设置太大的内存，防止执行 RDB 内存快照文件或者 AOF 重写的时候因数据太大而阻塞过长时间。



推荐最大设置为 `maxmemory 6GB`。



如果淘汰策略是 `noeviction`，当收到写请求，我将回复错误给客户端，读请求依然可以执行。



如果你把我当做一个 LRU 或 LFU 缓存系统的时候，那请用心关注以下配置。

### maxmemory-policy

设置内存淘汰策略，定义当内存满时如何淘汰 key，默认配置是 `noeviction`。



- volatile-lru -> 在设置过期时间的 key 中使用近似 LRU 驱逐。
- allkeys-lru -> 在所有 key 中使用近似 LRU 驱逐。
- volatile-lfu -> 在过期 key 中使用近似 LFU 驱逐。
- allkeys-lfu -> 在所有 key 中使用近似 LFU。
- volatile-random -> 在设置了过期时间的 key 中随机删除一个。
- allkeys-random -> 在所有的 key 中随机删除一个。
- volatile-ttl -> 谁快过期就删谁。
- noeviction -> 不删除任何 key，内存满了直接返回报错。

### maxmemory-samples

LRU, LFU and minimal TTL algorithms 不是精确的算法，是一个近似的算法(主要为了节省内存)。



所以需要你自己权衡速度和精确度。默认会抽取 5 个 key，选择一个最近最少使用的 key 淘汰，你可以改变这个数量。



默认的 5 可以提供不错的结果。配置 10 会非常接近真实的 LRU 但是会耗费更多的 CPU，配置 3 会更快，但是就不那么精确了。

### replica-ignore-maxmemory

从 Redis 5.0 开始，默认情况下 slave 节点会忽略 `maxmemory` 配置，除非在故障转移后或手动将其提升为 master。**这意味着只有 master 才会执行内存淘汰策略**，当 master 删除 key 后会发送 `DEL`指令给 slave。



默认配置`replica-ignore-maxmemory yes`。

### active-expire-effort

我有两种方式删除过期数据。



- 后台周期性选取部分数据删除。
- 惰性删除，当访问请求到某个 key 的时候，发现该 key 已经过期则删除。



这个配置用于指定过期 key 滞留在内存中的比例，默认值是 1，表示最多只能有 10 % 的过期 key 驻留在内存中，值设置的越小，那么一次淘汰周期内需需要消耗的 CPU 将会更多，因为需要删除更多的过期数据。

## 惰性释放

> MySQL：“ 可以使用非阻塞的方式删除 bigkey 么？”



我提供了两种删除 key 的基本命令用于删除数据。



- `DEL` 指令：这是一个阻塞的删除，执行该指令会停止处理写请求，使用同步的方式去回收 DEL 删除的对象的内存。如果这个 key 对应的 value 是一个非常小的对象， `DEL` 执行的时间非常短，时间复杂度为 O(1) 或者 O(log n)。如果 key 对应的 value 非常大，比如集合对象的数据包含百万个元素，服务器将阻塞很长时间（几秒钟）才能完成操作。
- `UNLINK（非阻塞删除）、(异步删除) FLUSHALL ASYNC/FLUSHDB ASYNC`：后台回收内存，这些指令在常量级别时间内执行，会使用一个新的线程在后台渐进的删除并释放内存（Lazy Free 机制）。

### lazyfree-lazy-eviction

由于 maxmemory 和 maxmemory-policy 策略配置，我会删除一些数据，防止内存爆掉。使用`lazyfree-lazy-eviction yes`表示使用 lazy free 机制，该场景开启 lazy free 可能会导致淘汰数据的内存释放不及时，出现内存超限。

### lazyfree-lazy-expire

对于设置了 TTL 的键，过期后删除。如果想启用 lazy free 机制删除，则配置 `lazyfree-lazy-eviction yes`。

### lazyfree-lazy-server-del

针对有些指令在处理已存在的键时，会带有一个隐式的 DEL 键的操作。



如 `rename` 命令，当目标键已存在，我会先删除目标键，如果这些目标键是一个 big key，那可能会出现阻塞删除的性能问题。 此参数设置就是解决这类问题，建议配置 `lazyfree-lazy-server-del yes` 开启。

### replica-lazy-flush

该配置针对 slave 进行全量数据同步，在加载 master 的 RDB 内存快照文件之前，会先运行 `flashall`清理数据的时候是否采用异步 flush 机制。



推荐你使用 `replica-lazy-flush yes`配置，可减少全量同步耗时，从而减少 master 因输出缓冲区暴涨引起的内存增长。

### lazyfree-lazy-user-del

意思是是否将 `DEL` 指令的默认行为替换成 lazy free 机制删除，效果就跟 `UNLINK` 一样，只要配置成 `lazyfree-lazy-user-del yes`。

### lazyfree-lazy-user-flush

`FLUSHDB, FLUSHALL, SCRIPT FLUSH, FUNCTION FLUSH`可以使用额外参数 `ASYNC|SYNC` 决定使用同步还是异步操作，当没有指定这个可选项，可以通过 `lazyfree-lazy-user-flush yes` 表示使用异步删除。

### IO 多线程

大家知道我是单线程模型处理读写请求，但是有一些操作可以使用其他线程处理，比如 `UNLINK`，I/O 读写操作。



在 6.0 版本，我提供了 I/O 多线程处理 Socket 读写，利用 I/O 多线程可以提高客户端 Socket 读写性能。



**默认配置是关闭的，我只建议当你的机器至少是 4 核 CPU 或者更多的情况启用，并且配置的线程数少于机器总 CPU 核数，配置超过 8 个线程对提升没什么帮助。**



当你的机器是四核 CPU，那可以尝试配置使用 2~3 个 I/O 线程，如果是 8 核 CPU，一般只需要配置 6 个线程。



如下配置表示开启 I/O 线程组，线程组的 I/O 线程数量为 3。



```shell
io-threads-do-reads yesio-threads 3
```

复制代码

## AOF 持久化

除了 RDB 内存快照文件作为持久化手段以外，还能使用 AOF(Append only file) 实现持久化，AOF 是一种可选的持久化策略提供更好数据安全性。



默认配置下，我最多只会丢失一秒的数据，你甚至可以配置更高级别，最多只丢失一次 write 操作，但这样会对损耗性能。

### appendonly

`appendonly yes` 表示开启 AOF 持久化，可以同时开启 AOF 和 RDB 内存快照持久化，如果开启了 AOF ，我会先加载 AOF 用于恢复内存数据。

### appendfilename

指定 AOF 文件名称，默认名字是 `appendonly.aof`。为了方便，你可以配置 `appenddirname` 指定 AOF 文件存储目录。

### appendfsync

调用操作系统的 `fsync()`函数告诉操作系统把输出缓冲区的数据持久化到磁盘， AOF 文件刷写的频率有三种。



- no：不去主动调用 fsync()，让操作系统自己决定何时写磁盘。
- always：每次 write 操作之后都调用 fsync()，非常慢，但是数据安全性最高。
- everysec：每秒调用一次 fsync()，一个折中的策略，最多丢失一秒的数据。



**默认配置是** `**appendfsync everysec**`**，推荐大家这么设置，兼顾了速度和数据安全。**

### no-appendfsync-on-rewrite

当 appendfsync 的配置设置成 `always`或者 `everysec` ，现在有一个后台 save 进程（可能是生成 RDB 内存快照的 bgsave 进程，也有可能是 AOF rewrite 进程）正在进行大量的磁盘 I/O 操作，会造成调用 `fsync()`执行太长，**后续其他想要调用** `**fsync()**` **的进程就会阻塞。**



为了缓解这个问题，可以使用以下配置 `no-appendfsync-on-rewrite yes` **表示当已经有** `**bgsave**`**和**`**bgrewriteaof**` **后台进程在调用** `**fsync()**` **时，不再开启新进程执行 AOF 文件写入。**



这样的话，就会出现当前有子进程在做 bgsave 或者其他的磁盘操作时，我就无法继续写 AOF 文件，这意味着可能会丢失更多数据。



如果有延迟问题，请将此选项改为 `yes`。否则将其保留为 `no`。从持久化的角度来看，`no`是最安全的选择。

### AOF 重写

为了防止 AOF 文件过大，antirez 大佬给我搞了个 AOF 重写机制。



`auto-aof-rewrite-percentage 100` 表示当前 AOF 文件大小超过上一次重写的 AOF 文件大小的百分之多少（如果没有执行过 AOF 重写，那就参照原始 AOF 文件大小），则执行 AOF 文件重写操作。



除了这个配置，你还要配置 `auto-aof-rewrite-min-size 64mb` 用于指定触发 AOF 重写操作的文件大小。



**如果该 AOF 文件大小小于该值，即使文件增长比例达到 100%，我也不会触发 AOF 重写操作，这是为了防止 AOF 文件其实很小，但是满足增长百分比时的多余 AOF 重写操作。**



**如果配置为**`**auto-aof-rewrite-percentage 0**` **，表示禁用 AOF 重写功能，建议大家开启 AOF 重写，防止文件过大。**

### aof-load-truncated

> MySQL：如果 AOF 文件是损坏的，你还加载数据还原到内存中么？



加载 AOF 文件把数据还原到内存中，文件可能是损坏的，比如文件末尾是错误的。这种情况一般是由于宕机导致，尤其是使用 ext4 文件系统挂载时没配置 `data=ordered` 选项。



在这种情况下，我可以直接报错，或者尽可能的读取可读的 AOF 内容。



如果配置成 `aof-load-truncated yes`，我依然会加载并读取这个损坏的 AOF 文件，并记录一个错误日志通知程序员。



配置成 `aof-load-truncated no`，我就会报错并拒绝启动服务，你需要使用 redis-check-aof 工具修复 AOF 文件，再启动 Redis。如果修复后还是错误，我依然报错并拒绝启动。

### aof-use-rdb-preamble

**这就是大名鼎鼎的 RDB-AOF 混合持久化功能，配置成** `**aof-use-rdb-preamble yes**`**（必须先开启 AOF），AOF 重写生成的文件将同时包含 RDB 格式的内容和 AOF 格式内容。**



混合持久化是在 AOF 重写完成的，开启混合持久化后，fork 出的子进程先将内存数据以 RDB 的方式写入 AOF 文件，接着把 RDB 格式数据写入 AOF 文件期间收到的增量命令从重写缓冲区以 AOF 格式写到文件中。



写入完成后通知主进程更新统计信息，并把含有 RDB 格式和 AOF 格式的 AOF 文件替换旧的 AOF 文件。



**这样的好处是可以结合 RDB 和 AOF 的优点，实现快速加载同时避免丢失过多数据，缺点是 AOF 文件的 RDB 部分内容不是 AOF 格式，可读性差（都是程序解析读取，哪个傻瓜程序员去读这个呀），强烈推荐你使用这个来保证持久化。**

### aof-timestamp-enabled

我在 7.0 版本新增的特性，大体就是讲 AOF 现在支持时间戳了，你可以做到基于时间点来恢复数据。



默认是是 `aof-timestamp-enabled no` 表示关闭该特性，你可以按照实际需求选择开启。

## Cluster 集群

Redis Cluster 集群相关配置，使用集群方式的你必须重视和知晓。别嘴上原理说的头头是道，而集群有哪些配置？如何配置让集群快到飞起，实现真正的高可用却一头雾水，通过下面这些配置详解也让你对集群原理更加深刻。

### cluster-enabled

普通的 Redis 实例是不能成为集群的一员，想要将该节点加入 Redis Cluster，需要设置 `cluster-enabled yes`。

### cluster-config-file

`cluster-config-file nodes-6379.conf` 指定集群中的每个节点文件。



集群中的每个节点都有一个配置文件，这个文件并不是让程序员编辑的，是我自己创建和更新的，每个节点都要使用不同的配置文件，一定要确保同一个集群中的不同节点使用的是不同的文件。

### cluster-node-timeout

设置集群节点不可用的最大超时时间，节点失效检测。集群中当一个节点向另一个节点发送 PING 命令，但是目标节点未在给定的时限内返回 PING 命令的回复时，那么发送命令的节点会将目标节点标记为 PFAIL(possible failuer，可能已失效)；



如果 master 节点超过这个时间还是无响应，则用它的从节点将启动故障迁移，升级成主节点。



默认配置是 `cluster-node-timeout 15000`，单位是毫秒数。

### cluster-port

该端口是集群总线监听 TCP 连接的端口，默认配置为 `cluster-port 0`，我就会把端口绑定为客户端命令端口 + 10000（客户端端口默认 6379，所以绑定为 16379 作为集群总线端口）。每个 Redis Cluster 节点都需要开放两个端口：



- 一个用于服务于客户端的 TCP 端口，比如 6379.
- 另一个称为集群总线端口，节点使用集群总线进行故障监测、配置更新、故障转移等。**客户端不要与集群总线端口通信，另外请确保在防火墙打开这两个端口，否则 Redis 集群之间将无法通信**。

### cluster-replica-validity-factor

该配置用于决定当 Redis Cluster 集群中，一个 master 宕机后，如何选择一个 slave 节点完成故障转移自动恢复（failover）。**如果设置为 0 ，则不管 slave 与 master 之间断开多久，都有资格成为 master。**



下面提供了两种方式来评估 slave 的数据是否太旧。



- 如果有多个 slave 可以 failover，他们之间会通过交换信息选出拥有拥有最大复制 offset 的 slave 节点。
- 每个 slave 节点计算上次与 master 节点交互的时间，这个交互包含最后一次 `ping` 操作、master 节点传输过来的写指令、上次与 master 断开的时间等。如果上次交互的时间过去很久，那么这个节点就不会发起 failover。



针对第二点，交互时间可以通过配置定义，如果 slave 与 master 上次交互的时间大于 `(node-timeout * cluster-replica-validity-factor) + repl-ping-replica-period`，该 slave 就不会发生 failover。



例如，``node-timeout = 30`秒，`cluster-replica-validity-factor=10`，`repl-ping-slave-period=10`秒， 表示 slave 节点与 master 节点上次交互时间已经过去了 310 秒，那么 slave 节点就不会做 failover。



调大 `cluster-replica-validity-factor` 则允许存储过旧数据的 slave 节点提升为 master，调小的话可能会导致没有 slave 节点可以升为 master 节点。



**考虑高可用，建议大家设置为** `**cluster-replica-validity-factor 0**`**。**

### cluster-migration-barrier

没有 slave 节点的 master 节点称为孤儿 master 节点，这个配置就是用于防止出现孤儿 master。



当某个 master 的 slave 节点宕机后，集群会从其他 master 中选出一个富余的 slave 节点迁移过来，确保每个 master 节点至少有一个 slave 节点，防止当孤立 master 节点宕机时，没有 slave 节点可以升为 master 导致集群不可用。



默认配置为 `cluster-migration-barrier 1`，是一个迁移临界值。



含义是：被迁移的 master 节点至少还有 1 个 slave 节点才能做迁移操作。比如 master A 节点有 2 个以上 slave 节点 ，当集群出现孤儿 master B 节点时，A 节点富余的 slave 节点可以迁移到 master B 节点上。



生产环境建议维持默认值，最大可能保证高可用，设置为非常大的值或者配置 `cluster-allow-replica-migration no` 禁用自动迁移功能。



`cluster-allow-replica-migration` 默认配置为 yes，表示允许自动迁移。

### cluster-require-full-coverage

**默认配置是** `**yes**`**，表示为当 redis cluster 发现还有哈希槽没有被分配时禁止查询操作。**



这就会导致集群部分宕机，整个集群就不可用了，当所有哈希槽都有分配，集群会自动变为可用状态。



如果你希望 cluster 的子集依然可用，配置成 `cluster-require-full-coverage no`。

### cluster-replica-no-failover

当配置成 `yes`，在 master 宕机时，slave 不会做故障转移升为 master。



**这个配置在多数据中心的情况下会很有用，你可能希望某个数据中心永远不要升级为 master 节点，否则 master 节点就漂移到其他数据中心了，正常情况设置成 no。**

### cluster-allow-reads-when-down

默认是 `no`，表示当集群因主节点数量达不到最小值或者哈希槽没有完全分配而被标记为失效时，节点将停止所有客户端请求。



**设置成** `**yes**`**，则允许集群失效的情况下依然可从节点中读取数据，保证了高可用。**

### cluster-allow-pubsubshard-when-down

配置成 `yes`，表示当集群因主节点数量达不到最小值或者哈希槽没有完全分配而被标记为失效时，pub/sub 依然可以正常运行。

### cluster-link-sendbuf-limit

设置每个集群总线连接的发送字节缓冲区的内存使用限制，超过限制缓冲区将被清空（主要为了防止发送缓冲区发送给慢速连接时无限延长时间的问题）。



默认禁用，建议最小设置 1gb，这样默认情况下集群连接缓冲区可以容纳至少一条 pubsub 消息（client-query-buffer-limit 默认是 1gb）；

## 性能监控

### 慢查询日志

慢查询（Slow Log）日志是我用于记录慢查询执行时间的日志系统，只要查询超过配置的时间，都会记录。slowlog 只保存在内存中，因此效率很高，大家不用担心会影响到 Redis 的性能。



执行时间不包括 I/O 操作的时间，比如与客户端建立连接、发送回复等，只记录执行命令执行阶段所需要的时间。



你可以使用两个参数配置慢查询日志系统。



- `slowlog-log-slower-than`：指定对执行时间大于多少微秒（microsecond，1 秒 = 1,000,000 微秒）的查询进行记录，默认是 10000 微妙，推荐你先执行基线测试得到一个基准时间，通常这个值可以设置为基线性能最大延迟的 3 倍。
- `slowlog-max-len`：设定最多保存多少条慢查询的日志，slowlog 本身是一个 FIFO 队列，当超过设定的最大值后，我会把最旧的一条日志删除。默认配置 128，如果设置太大会占用多大内存。

### 延迟监控

延迟监控（LATENCY MONITOR）系统会在运行时抽样部分命令来帮助你分析 Redis 卡顿的原因。



通过 `LATENCY`命令，可以打印一些视图和报告，系统只会记录大于等于指定值的命令。



默认配置 `latency-monitor-threshold 0`，设置 0 表示关闭这个功能。**没有延迟问题，没必要开启开启监控，因为会对性能造成很大影响。**



在运行过程中你怀疑有延迟性能问题，想要监控的话可以使用 `CONFIG SET latency-monitor-threshold <milliseconds>`开启，单位是毫秒。

## 高级设置

这部分配置主要围绕以下几个方面。



- 指定不同数据类型根据不同条数下使用不同的数据结构存储，合理配置能做到更快和更省内存。
- 客户端缓冲区相关配置。
- 渐进式 rehash 资源控制。
- LFU 调优。
- RDB 内存快照文件、AOF 文件同步策略。

### Hashes（散列表）

在 Redis 7.0 版本散列表数据类型有两种数据结构保存数据，分别为散列表和 listpack。当数据量很小时，可以使用更高效的数据结构存储，从而达到在不影响性能的情况下节省内存。



- `hash-max-listpack-entries 512`：指定使用 listpack 存储的最大条目数。
- `hash-max-listpack-value 64`：listpack 中，条目 value 值最大字节数，建议设置成 1024。



在 7.0 版本以前，使用的是 ziplist 数据结构，配置如下。



```shell
hash-max-ziplist-entries 512hash-max-ziplist-value 64
```

复制代码

### Lists（列表）

Lists 也可以使用一种特殊方式进行编码来节省大量内存空间。在 Redis 7.0 之后，Lits 底层的数据结构使用 linkedlist 或者 listpack 。



Redis 3.2 版本，List 内部是通过 linkedlist 和 quicklist 实现，quicklist 是一个双向链表， quicklist 的每个节点都是一个 ziplist，从而实现节省内存。



元素少时用 quicklist，元素多时用 linkedlist。listpack 的目的就是用于替代 ziplist 和 quicklist。listpack 也叫**紧凑列表**，它的特点就是用一块连续的内存空间来紧凑地保存数据，同时为了节省内存空间



**list-max-ziplist-size**



7.0 版本之前`list-max-ziplist-size` 用于配置 quicklist 中的每个节点的 ziplist 的大小。 当这个值配置**为正数时表示 quicklist 每个节点的 ziplist 最多可存储元素数量**，超过该值就会使用 linkedlist 存储。



当 `list-max-ziplist-size` **为负数时表示限制每个 quicklistNode 的 ziplist 的内存大小**，超过这个大小就会使用 linkedlist 存储数据，每个值有以下含义：



- -5：每个 quicklist 节点上的 ziplist 大小最大 64 kb <--- 正常环境不推荐
- -4：每个 quicklist 节点上的 ziplist 大小最大 32 kb <--- 不推荐
- -3：每个 quicklist 节点上的 ziplist 大小最大 16 kb <--- 可能不推荐
- -2：每个 quicklist 节点上的 ziplist 大小最大 8 kb <--- 不错
- -1：每个 quicklist 节点上的 ziplist 大小最大 4kb <--- 不错



默认值为 -2，也是官方最推荐的值，当然你可以根据自己的实际情况进行修改。



**list-max-listpack-size**



7.0 之后，配置修改为`list-max-listpack-size -2`则表示限制每个 listpack 大小，不再赘述。



**list-compress-depth**



压缩深度配置，用来配置压缩 Lists 的，当 Lists 底层使用 linkedlist 也是可以压缩的，默认是 `list-compress-depth 0`表示不压缩。一般情况下，Lists 的两端访问的频率高一些，所以你可以考虑把中间的数据进行压缩。



不同参数值的含义如下。



- 0，关闭压缩，默认值。
- 1，两端各有一个节点不压缩。
- 2，两端各有两个节点不压缩。
- N，依次类推，两端各有 N 个节点不压缩。



**需要注意的是，head 和 tail 节点永远都不会被压缩。**

### Sets（无序集合）

Sets 底层的数据结构可以是 intset（整形数组）和 Hashtable（散列表），intset 你可以理解成数组，Hashtable 就是普通的散列表（key 存的是 Sets 的值，value 为 null）。有没有觉得 Sets 使用散列表存储是意想不到的事情？



**set-max-intset-entries**



当集合的元素都是 64 位以内的十进制整数时且长度不超过 `set-max-intset-entries` 配置的值（默认 512），Sets 的底层会使用 intset 存储节省内存。添加的元素大于 `set-max-intset-entries`配置的值，底层实现由 intset 转成散列表存储。

### SortedSets（有序集合）

在 Redis 7.0 版本之前，有序集合底层的数据结构有 ziplist 和 skipist，之后使用 listpack 代替了 ziplist。



7.0 版本之前，当集合元素个数小于 `zset-max-ziplist-entries`配置，同时且每个元素的值大小都小于`zset-max-ziplist-value`配置（默认 64 字节，推荐调大到 128）时，我将使用 ziplist 数据结构存储数据，有效减少内存使用。与此类似，7.0 版本之后我将使用 listpack 存储。



```shell
## 7.0 之前的配置zset-max-ziplist-entries 128zset-max-ziplist-value 64## 7.0 之后的配置zset-max-listpack-entries 128zset-max-listpack-value 64
```

复制代码

### HyperLogLog

HyperLogLog 是一种高级数据结构，统计基数的利器。**HyperLogLog 的存储结构分为密集存储结构和稀疏存储结构两种，默认为稀疏存储结构，而我们常说的占用 12K 内存的则是密集存储结构，稀疏结构占用的内存会更小。**



**hll-sparse-max-bytes**



默认配置是 `hll-sparse-max-bytes 3000`，单位是 Byte，这个配置用于决定存储数据使用稀疏数据结构（sparse）还是稠密数据结构（dense）。



如果 HyperLogLog 存储内容大小大于 hll-sparse-max-bytes 配置的值将会转换成稠密的数据结构（dense）。



推荐的值是 0~3000，这样`PFADD`命令的并不会慢多少，还能节省空间。如果内存空间相对 cpu 资源更缺乏，可以将这个值提升到 10000。

### Streams（流）

Stream 是 Redis 5.0 版本新增的数据类型。Redis Streams 是一些由基数树（Radix Tree）连接在一起的节点经过 delta 压缩后构成的，这些节点与 Stream 中的消息条目（Stream Entry）并非一一对应，而是**每个节点中都存储着若干 Stream 条目**，因此这些节点也被称为宏节点或大节点。



**stream-node-max-bytes 4096**



单位为 Byte，默认值 4096，用于设定每个宏节点占用的内存上限为 4096，0 表示无限制。



**stream-node-max-entries 100**



用于设定每个宏节点存储元素个数。 默认值 100，0 表示无限制。当一个宏节点存储的 Stream 条目到达上限，新添加的条目会存储到新的宏节点中。

### rehash

我采用的是渐进式 rehash，这是一个惰性策略，不会一次性把所有数据迁移完，而是分散到每次请求中，这样做的目的是防止数据太多要迁移阻塞主线程。



**在渐进式 rehash 的同时，推荐你使用** `**activerehashing yes**`**开启定时辅助执行 rehash，默认情况下每一秒执行 10 次 rehash 加快迁移速度，尽可能释放内存。**



关闭该功能的话，如果这些 key 不再活跃不被被访问到，rehash 操作可能不再有机会完成，会导致散列表占用更多内存。

### 客户端输出缓冲区限制

这三个配置是用来强制断开客户端连接的，当客户端没有及时把缓冲区的数据读取完毕，我会认为这个客户端可能完蛋了（一个常见的原因是 Pub/Sub 客户端处理发布者的消息不够快），于是断开连接。



一共分为三种不同类型的客户端，分别设置不同的限制。



- normal（普通），普通客户端，包括 MONITOR 客户端。
- replica（副本客户端），slave 节点的客户端。
- pubsub（发布订阅客户端），至少订阅了一个 pubsub 频道或者模式的客户端。



`client-output-buffer-limit`的语法如下。



```shell
client-output-buffer-limit <class> <hard limit> <soft limit> <soft seconds>
```

复制代码



<class> 表示不同类型的客户端，当客户端的缓冲区内容大小达到 <hard limit>后我就立马断开与这个客户端的连接，或者达到 <soft limit> 并持续了 <soft seconds>秒后断开。



默认情况下，普通客户端不会限制，只有后异步的客户端才可能发送发送请求的速度比读取响应速度快的问题。比如 pubsub 和 replica 客户端会有默认的限制。



soft limit 或者 hard limit 设置为 0，表示不启用此限制。默认配置如下。



```shell
client-output-buffer-limit normal 0 0 0client-output-buffer-limit replica 256mb 64mb 60client-output-buffer-limit pubsub 32mb 8mb 60
```

复制代码

### client-query-buffer-limit

每个客户端都有一个 query buffer（查询缓冲区或输入缓冲区），用于保存客户端发送命令，Redis Server 从 query buffer 获取命令并执行。



如果程序的 Key 设计不合理，客户端使用大量的 query buffer，导致 Redis 很容易达到 maxmeory 限制。最好限制在一个固定的大小来避免占用过大内存的问题。



如果你需要发送巨大的 multi/exec 请求的时候，那可以适当修改这个值以满足你的特殊需求。



默认配置为 `client-query-buffer-limit 1gb`。

### maxmemory-clients

这是 7.0 版本特性，每个与服务端建立连接的客户端都会占用内存（查询缓冲区、输出缓冲区和其他缓冲区），大量的客户端可能会占用过大内存导致 OOM，为了避免这个情况，我提供了一种叫做（Client Eviction）客户端驱逐机制用于限制内存占用。



配置方式有两种。



- 具体内存值， `maxmemory-clients 1g`来限制所有客户端占用内存总和。
- 百分比，`maxmemory-clients 5%` 表示客户端总和内存占用最多为 Redis 最大内存配置的 5%。



默认配置是 `maxmemory-clients 0` 表示无限制。



> MySQL：“达到最大内存限制，你会把所有客户端连接都释放么？”



不是的，一旦达到限制，我会优先尝试断开使用内存最多的客户端。

### proto-max-bulk-len

批量请求（单个字符串的元素）内存大小限制，默认是 `proto-max-bulk-len 512mb`，你可以修改限制，但必须大于等于 1mb。

### hz

我会在后台调用一些函数来执行很多后台任务，比如关闭超时连接，清理不再被请求的过期的 key，rehash、执行 RDB 内存快照和 AOF 持久化等。



并不是所有的后台任务都需要使用相同的频率来执行，你可以使用 hz 参数来决定执行这些任务的频率。



默认配置是 `hz 10`，表示每秒执行 10 次，更大的值会消耗更多的 CPU 来处理后台任务，带来的效果就是更快的清理过期 key，清理的超时连接更精确。



**这个值的范围是 1~500，不过并不推荐设置大于 100 的值。大家使用默认值就好，或者最多调高到 100。**

### dynamic-hz

默认配置是 `dynamic-hz yes`，启用 dynamic-hz 后，将启用自适应 HZ 值的能力。hz 的配置值将会作为基线，Redis 服务中的实际 hz 值会在基线值的基础上根据已连接到 Redis 的客户端数量自动调整，连接的客户端越多，实际 hz 值越高，Redis 执行定期任务的频率就越高。

### `aof-rewrite-incremental-fsync` 

当子进程进行 AOF 重写时，如果配置成 `aof-rewrite-incremental-fsync yes`，每生成 4 MB 数据就执行一次 `fsync`操作，分批提交到硬盘来避免高延迟峰值，推荐开启。

### rdb-save-incremental-fsync

当我在保存 RDB 内存快照文件时，如果配置成 `db-save-incremental-fsync yes`，每生成 4MB 文件就执行一次 `fsync`操作，分批提交到硬盘来避免高延迟峰值，推荐开启。

### LFU 调优

这个配置生效的前提是内存淘汰策略设置的是 `volatile-lfu`或`allkeys-lfu`。



- lfu-log-factor 用于调整 Logistic Counter 的增长速度，lfu-log-factor 值越大，Logistic Counter 增长越慢。默认配置 10。

- 以下是表格是官方不同 factor 配置下，计数器的改变频率。注意：表格是通过如下命令获得的： `redis-benchmark -n 1000000 incr foo redis-cli object freq foo`。

- 

  

- lfu-decay-time 用于调整 Logistic Counter 的衰减速度，它是一个以分钟为单位的数值，默认值为 1；lfu-decay-time 值越大，衰减越慢。

## 在线内存碎片整理

> MySQL：“什么是在线内存碎片整理？”



Active (online) defragmentation 在线内存碎片整理指的是自动压缩内存分配器分配和 Redis 频繁做更新操作、大量过期数据删除，释放的空间（不够连续）无法得到复用的内存空间。



通常来说当碎片化达到一定程度（查看下面的配置）Redis 会使用 Jemalloc 的特性创建连续的内存空间， 并在此内存空间对现有的值进行拷贝，拷贝完成后会释放掉旧的数据。 这个过程会对所有的导致碎片化的 key 以增量的形式进行。



**需要注意的是**



1. 这个功能默认是关闭的，并且只有在编译 Redis 时使用我们代码中的 Jemalloc 版本才生效。（这是 Linux 下的默认行为）。
2. 在实际使用中，建议是在 Redis 服务出现较多的内存碎片时启用（内存碎片率大于 1.5），正常情况下尽量保持禁用状态。
3. 如果你需要试验这项特性，可以通过命令 `CONFIG SET activefrag yes`来启用。



**清理的条件**



`activefrag yes`：内存碎片整理总开关，默认为禁用状态 no。



`active-defrag-ignore-bytes 200mb`：内存碎片占用的内存达到 200MB。



`active-defrag-threshold-lower 20`：内存碎片的空间占比超过系统分配给 Redis 空间的 20% 。



**在同时满足上面三项配置时，内存碎片自动整理功能才会启用。**



**CPU 资源占用**



> MySQL：如何避免自动内存碎片整理对性能造成影响？



清理的条件有了，还需要分配清理碎片占用的 CPU 资源，保证既能正常清理碎片，又能避免对 Redis 处理请求的性能影响。



`active-defrag-cycle-min 5`：自动清理过程中，占用 CPU 时间的比例不低于 5%，从而保证能正常展开清理任务。



`active-defrag-cycle-max 20`：自动清理过程占用的 CPU 时间比例不能高于 20%，超过的话就立刻停止清理，避免对 Redis 的阻塞，造成高延迟。



**整理力度**



`active-defrag-max-scan-fields 1000`：碎片整理扫描到`set/hash/zset/list` 时，仅当 `set/hash/zset/list`的长度小于此阀值时，才会将此键值对加入碎片整理，大于这个值的键值对会放在一个列表中延迟处理。



`active-defrag-threshold-upper 100`：内存碎片空间占操作系统分配给 Redis 的总空间比例达此阈值（默认 100%），我会尽最大努力整理碎片。建议你调整为 80。

### jemalloc-bg-thread

默认配置为 `jemalloc-bg-thread yes`，表示启用清除脏页后台线程。

### 绑定 CPU

你可以将 Redis 的不同线程和进程绑定到特定的 CPU，减少上下文切换，提高 CPU L1、L2 Cache 命中率，实现最大化的性能。



你可以通过修改配置文件或者`taskset`命令绑定。



可分为三个模块。



- 主线程和 I/O 线程：负责命令读取、解析、结果返回。命令执行由主线程完成。
- bio 线程：负责执行耗时的异步任务，如 close fd、AOF fsync 等。
- 后台进程：fork 子进程（RDB bgsave、AOF rewrite bgrewriteaof）来执行耗时的命令。



Redis 支持分别配置上述模块的 CPU 亲合度，默认情况是关闭的。



- `server_cpulist 0-7:2`，I/O 线程（包含主线程）相关操作绑定到 CPU 0、2、4、6。
- `bio_cpulist 1,3`，bio 线程相关的操作绑定到 CPU 1、3。
- `aof_rewrite_cpulist`，aof rewrite 后台进程绑定到 CPU 8、9、10、11。
- `bgsave_cpulist 1,10-11`，bgsave 后台进程绑定到 CPU 1、10、11。



**注意事项**



1. Linux 下，使用 **「numactl --hardware」** 查看硬件布局，确保支持并开启 NUMA。
2. 线程要尽可能分布在 **不同的 CPU，相同的 node**，设置 CPU 亲和度才有效，否则会造成频繁上下文切换。
3. 你要熟悉 CPU 架构，做好充分的测试。否则可能适得其反，导致 Redis 性能下降。

发布于: 2023-01-12阅读数: 4423

版权声明: 本文为 InfoQ 作者【码哥字节】的原创文章。

原文链接:【https://xie.infoq.cn/article/906db4e8327990c309fc7554f】。未经作者许可，禁止转载。

[NoSQL 数据库](https://xie.infoq.cn/tag/14599)[redis 底层原理](https://xie.infoq.cn/tag/21420)[Redis 7](https://xie.infoq.cn/tag/26487)