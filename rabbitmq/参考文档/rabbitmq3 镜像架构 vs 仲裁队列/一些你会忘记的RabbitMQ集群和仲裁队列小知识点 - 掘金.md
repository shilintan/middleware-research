# 一些你会忘记的RabbitMQ集群和仲裁队列小知识点

[啵啵肠](https://juejin.cn/user/1187904004821262/posts)

2022-11-29 18:14235

开启掘金成长之旅！这是我参与「掘金日新计划 · 12 月更文挑战」的第7天，[点击查看活动详情](https://juejin.cn/post/7167294154827890702)

# RabbitMQ集群

今天我们来学习如何避免单点的MQ故障而导致的不可用问题，这个就要靠MQ的集群去实现了。

# 1、集群分类

> **RabbitMQ**的是基于**Erlang**语言编写，而**Erlang**又是一个面向并发的语言，天然支持集群模式。**RabbitMQ**的集群有两种模式：

## 1.1 普通集群

> 是一种分布式集群，将队列分散到集群的各个节点，从而提高整个集群的并发能力。
>
> 这种集群有一个问题，一旦集群中某个节点出现了故障，那这个节点上的队列，以及上面的消息就全都没了，所以它会存在一定的安全问题。

### 1.1.1 集群结构和特征

普通集群，或者叫标准集群（classic cluster），具备下列特征：

> 1. 会在集群的各个节点间共享部分数据，包括：交换机、队列元信息（队列的描述信息，包括队列名字，队列节点，队列有什么消息）。不包含消息本身。
> 2. 当访问集群某节点时，如果队列不在该节点，会从数据所在节点传递到当前节点并返回
> 3. 队列所在节点宕机，队列中的消息就会丢失

结构如图：

![1](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/d204f2ba5d754738bb8dcb57d1833f51~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

### 1.1.2 部署

我们的计划部署3节点的mq集群：

![2](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/805bfe94f20448fc9963df935498944a~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

这里三个主机就是三台机器，这里我用三个Docker代替了。

集群中的节点标示默认都是：`rabbit@[hostname]`，因此以上三个节点的名称分别为：

> - rabbit@mq1
> - rabbit@mq2
> - rabbit@mq3

#### 1、获取cookie

> RabbitMQ底层依赖于Erlang，而Erlang虚拟机就是一个面向分布式的语言，默认就支持集群模式。集群模式中的每个RabbitMQ 节点使用 cookie 来确定它们是否被允许相互通信。
>
> 要使两个节点能够通信，它们必须具有相同的共享秘密，称为**Erlang cookie**。cookie 只是一串最多 255 个字符的字母数字字符。
>
> 每个集群节点必须具有**相同的 cookie**。实例之间也需要它来相互通信。

我们先在之前启动mq容器中获取一个cookie值，作为集群的cookie。执行下面的命令：

```bash
bash
复制代码docker exec -it mq cat /var/lib/rabbitmq/.erlang.cookie
```

可以看到我的cookie值如下：

![3](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/517d01ffbf72495e8743f0840cb77eb0~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

接下来，停止并删除当前的mq容器，我们重新搭建集群。

```bash
bash
复制代码docker rm -f mq
```

![4](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9fb3e40cc8db4e16bd8d419eea614135~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

#### 2、准备集群配置

在/tmp目录新建一个配置文件 rabbitmq.conf：

```bash
bash复制代码cd /tmp
# 创建文件
touch rabbitmq.conf
```

![5](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/d370ad09ca474181b0f359d3c5a9e387~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

文件内容如下：

![6](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/2b386576fdd5460b96dd0381334f66cd~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

```ini
ini复制代码loopback_users.guest = false
listeners.tcp.default = 5672
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_classic_config
cluster_formation.classic_config.nodes.1 = rabbit@mq1
cluster_formation.classic_config.nodes.2 = rabbit@mq2
cluster_formation.classic_config.nodes.3 = rabbit@mq3
```

> 文件解析：
>
> **loopback_users.guest =false**:禁用guest用户，因为RabbitMQ客户端有一个guest用户，所以我们把它禁用掉，防止有些不法分子来访问我们。
>
> **listeners.tcp.default = 5672**：监听端口，用于消息通信
>
> 最重要的是下面三个：
>
> cluster_formation.classic_config.nodes.1 = rabbit@mq1 cluster_formation.classic_config.nodes.2 = rabbit@mq2 cluster_formation.classic_config.nodes.3 = rabbit@mq3
>
> 这里配置的分别集群中的节点信息。

再创建一个文件，记录cookie

```bash
bash复制代码cd /tmp
# 创建cookie文件
touch .erlang.cookie
# 写入cookie
echo "NEHXVEBVVLVHYDWCAFVH" > .erlang.cookie
# 修改cookie文件的权限
chmod 600 .erlang.cookie
```

准备三个目录,mq1、mq2、mq3：

```bash
bash复制代码cd /tmp
# 创建目录
mkdir mq1 mq2 mq3
```

然后拷贝rabbitmq.conf、cookie文件到mq1、mq2、mq3：

```bash
bash复制代码# 进入/tmp
cd /tmp
# 拷贝
cp rabbitmq.conf mq1
cp rabbitmq.conf mq2
cp rabbitmq.conf mq3
cp .erlang.cookie mq1
cp .erlang.cookie mq2
cp .erlang.cookie mq3
```

#### 3、启动集群

创建一个网络：

```lua
lua
复制代码docker network create mq-net
```

![7](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/eed3d68fe7024d7296262d033f6d6e0e~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

运行命令

mq1:

```diff
diff复制代码docker run -d --net mq-net \
-v ${PWD}/mq1/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf \
-v ${PWD}/.erlang.cookie:/var/lib/rabbitmq/.erlang.cookie \
-e RABBITMQ_DEFAULT_USER=jie \
-e RABBITMQ_DEFAULT_PASS=123456 \
--name mq1 \
--hostname mq1 \
-p 8071:5672 \
-p 8081:15672 \
rabbitmq:3.8-management
```

mq2:

```diff
diff复制代码docker run -d --net mq-net \
-v ${PWD}/mq2/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf \
-v ${PWD}/.erlang.cookie:/var/lib/rabbitmq/.erlang.cookie \
-e RABBITMQ_DEFAULT_USER=jie \
-e RABBITMQ_DEFAULT_PASS=123456 \
--name mq2 \
--hostname mq2 \
-p 8072:5672 \
-p 8082:15672 \
rabbitmq:3.8-management
```

mq3:

```diff
diff复制代码docker run -d --net mq-net \
-v ${PWD}/mq3/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf \
-v ${PWD}/.erlang.cookie:/var/lib/rabbitmq/.erlang.cookie \
-e RABBITMQ_DEFAULT_USER=jie \
-e RABBITMQ_DEFAULT_PASS=123456 \
--name mq3 \
--hostname mq3 \
-p 8073:5672 \
-p 8083:15672 \
rabbitmq:3.8-management
```

打开浏览器

![9](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/768cab131b3c4df384c464893bdc852b~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

#### 4.测试

在mq1这个节点上添加一个队列：

![10](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/5452a47cee714e80a0140ec5a0d1bd18~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

然后我们去mq2和mq3那里也能看到这个队列。

![11](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/e554179f0fac4b5fbac68af1008232d3~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

##### 4.1 数据共享测试

点击这个队列，进入管理页面：

![12](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/caa78a6f18a64fb49c9749e597c7c1d3~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

然后利用控制台发送一条消息到这个队列：

![13](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/0720a8152bff4b3aa7e98b4880cb08f7~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

结果在mq2、mq3上都能看到这条消息：

![14](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/8b6bb6d58be648e69e9a130fb9249525~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

##### 4.2 可用性测试

我们让其中一台节点mq1宕机：

```arduino
arduino
复制代码docker stop mq1
```

![15](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/f95a2e53999242fd803b5feb5ec76400~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

然后登录mq2或mq3的控制台，发现simple.queue也不可用了：

![16](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/e9a49c17ca5948df9f39c04747561963~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

说明数据并没有拷贝到mq2和mq3。

## 1.2 镜像集群

在刚刚的案例中，一旦创建队列的主机宕机，队列就会不可用。不具备高可用能力。如果要解决这个问题，必须使用官方提供的镜像集群方案。

官方文档地址：[www.rabbitmq.com/ha.html](https://link.juejin.cn/?target=https%3A%2F%2Fwww.rabbitmq.com%2Fha.html)

> 镜像集群是一种主从集群，普通集群的基础上，添加了主从备份功能，提高集群的数据可用性。
>
> 这种集群有一个问题，主从数据源要同步，要从主节点同步到从节点，但是这个主从同步它不是强一致的，存在一定的延迟，如果在主从同步期间出现了一点故障，就可能导致**数据丢失**。
>
> 因此在**RabbitMQ**的**3.8**版本以后，推出了新的功能：**仲裁队列**来代替镜像集群，底层采用Raft协议确保主从的数据一致性。

### 1.2.1 集群结构和特征

> - 交换机、队列、队列中的消息会在各个mq的镜像节点之间同步备份。
> - 创建队列的节点被称为该队列的**主节点，** 备份到的其它节点叫做该队列的**镜像**节点。
> - 一个队列的主节点可能是另一个队列的镜像节点。
> - 不具备负载均衡功能，因为所有操作都是主节点完成，然后同步给镜像节点。
> - 主宕机后，镜像节点会替代成新的主节点。

结构如图：

![17](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/b5513e16496e49e3b71d8dd0adae8078~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

### 1.2.2 部署

镜像集群的配置有3种模式：

![18](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/a726a7b054f249eaa3af6def27616cf2~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

这里我们以rabbitmqctl命令作为案例来讲解配置语法。

语法示例：

#### 1、exactly模式

首先进入任意一个节点

```json
json
复制代码rabbitmqctl set_policy ha-two "^two." '{"ha-mode":"exactly","ha-params":2,"ha-sync-mode":"automatic"}'
```

![20](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/01e737d8bf534f61b828c566059b751b~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

> - rabbitmqctl set_policy`：固定写法
> - `ha-two`：策略名称，自定义
> - `"^two."`：匹配队列的正则表达式，符合命名规则的队列才生效，这里是任何以`two.`开头的队列名称
> - `'{"ha-mode":"exactly","ha-params":2,"ha-sync-mode":"automatic"}'`: 策略内容
>   - `"ha-mode":"exactly"`：策略模式，此处是exactly模式，指定副本数量
>   - `"ha-params":2`：策略参数，这里是2，就是副本数量为2，1主1镜像
>   - `"ha-sync-mode":"automatic"`：同步策略，默认是manual，即新加入的镜像节点不会同步旧的消息。如果设置为automatic，则新加入的镜像节点会把主节点中所有消息都同步，会带来额外的网络开销

然后退出 exit，我们进入浏览器查看。

![21](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9ccaed8bf94d41fab6283aecacd314ec~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

我们创建一个新的队列：

![22](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/961304141626490baa0fbf415b733578~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

在任意一个mq控制台查看队列：

![23](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/bc9e0a6ef12342df8421a629e6cfc629~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

测试数据共享，给two.queue发送一条消息：

![24](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/1ce62c65b46d477cb097c273c094b396~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

然后在mq1、mq2、mq3的任意控制台查看消息：

![25](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/a6b5bfbc7fb94ff094dff36891d56df3~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

测试高可用，现在，我们让two.queue的主节点mq1宕机：

```arduino
arduino
复制代码docker stop mq1
```

然后我们先看集群状态

![27](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/be454b6365304bea9931a42e826f74b9~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

再看队列状态：

![26](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fa3e2d19a89344599bfb7e8f9a855a33~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

发现依然是健康的！并且其主节点切换到了rabbit@mq2上。

剩下的模式，大家可以自己去试试，大同小异。

#### 2、all模式

```css
css
复制代码rabbitmqctl set_policy ha-all "^all." '{"ha-mode":"all"}'
```

- `ha-all`：策略名称，自定义
- `"^all."`：匹配所有以`all.`开头的队列名
- `'{"ha-mode":"all"}'`：策略内容
  - `"ha-mode":"all"`：策略模式，此处是all模式，即所有节点都会称为镜像节点

#### 3、nodes模式

```json
json
复制代码rabbitmqctl set_policy ha-nodes "^nodes." '{"ha-mode":"nodes","ha-params":["rabbit@nodeA", "rabbit@nodeB"]}'
```

- `rabbitmqctl set_policy`：固定写法
- `ha-nodes`：策略名称，自定义
- `"^nodes."`：匹配队列的正则表达式，符合命名规则的队列才生效，这里是任何以`nodes.`开头的队列名称
- `'{"ha-mode":"nodes","ha-params":["rabbit@nodeA", "rabbit@nodeB"]}'`: 策略内容
  - `"ha-mode":"nodes"`：策略模式，此处是nodes模式
  - `"ha-params":["rabbit@mq1", "rabbit@mq2"]`：策略参数，这里指定副本所在节点名称

# 2、仲裁队列

> 从RabbitMQ 3.8版本开始，引入了新的仲裁队列，他具备与镜像队里类似的功能，但使用更加方便，它具备以下特征。

- 与镜像队列一样，都是主从模式，支持主从数据同步
- 使用非常简单，没有复杂的配置
- 主从同步基于Raft协议，强一致

## 2.1 部署

在任意控制台添加一个队列，一定要选择队列类型为Quorum类型。

![28](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/19051f3245be4c2496181323cd28b00b~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

在任意控制台查看队列：

![29](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/f7b5bc6898f7451fb5bba283e00128e9~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)

可以看到，仲裁队列的 + 2字样。代表这个队列有2个镜像节点。

因为仲裁队列默认的镜像数为5。如果你的集群有7个节点，那么镜像数肯定是5；而我们集群只有3个节点，因此镜像数量就是3.

测试参考镜像集群的方式，效果是一样的。

## 2.2 .Java代码创建仲裁队列

要创建仲裁队列记得先去配置集群。

```typescript
typescript复制代码@Bean
public Queue quorumQueue() {
    return QueueBuilder
        .durable("quorum.queue") // 持久化
        .quorum() // 仲裁队列
        .build();
}
```

## 2.3 SpringAMQP连接MQ集群

注意，这里用address来代替host、port方式

```yaml
yaml复制代码spring:
  rabbitmq:
    addresses: 192.168.58.149:8081, 192.168.58.149:8082, 192.168.58.149:8083
    username: jie
    password: 123456
    virtual-host: /
```

标签：

[RabbitMQ](https://juejin.cn/tag/RabbitMQ)[掘金·日新计划](https://juejin.cn/tag/掘金·日新计划)