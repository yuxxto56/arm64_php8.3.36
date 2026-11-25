# 构建流程（香港服务器构建顺畅）

#### 一、amd64架构构建

+ 选择一台x86机器进入构建目录直接构建即可
  > docker build -t  php-fpm:8.3.36-arm64-prod-v001:latest .
  >

#### 二、arm64架构构建

+ 选择aarch机器直接构建即可
+ 选择x86机器构建需要进行跨平台编译构建，构建方式如下：

##### 跨平台编译背景

> 在x86-64环境下编译适用于arm64平台的docker镜像

##### 跨平台编译过程

1、docker环境

> 本实验通过ubuntu24.10 amd64环境中使用docker 27.4.0版本下进行中，方案可行

2、docker配置

> 修改/etc/docker/daemon.json文件，添加"experimental": true
>
> systemctl daemon-reload
>
> systemctl restart docker.service

3、buildx查看

> docker buildx version  //查看版本
>
> docker buildx ls     //查看编辑器列表

4、启用binfmt\_misc，运行一个[特权容器](https://zhida.zhihu.com/search?content_id=240838342&content_type=Article&match_order=1&q=%E7%89%B9%E6%9D%83%E5%AE%B9%E5%99%A8&zhida_source=entity)，容器里面写好了设置脚本

> docker run --privileged --rm tonistiigi/binfmt:latest --install all   //启动容器
>
> ll /proc/sys/fs/binfmt_misc/  //验证是否安装好misc
>
> cat /proc/sys/fs/binfmt_misc/qemu-aarch64  //验证是否启用了目标编译平台

5、创建自定义buildx构建器

> docker buildx create --use --name mybuilder  //创建一个自定义构建器
>
> docker buildx inspect mybuilder --bootstrap  //启动自定义构建器
>
> docker buildx ls  //再次查看自定义的构建器信息

6、编译跨平台镜像

>
> docker buildx build -t php-fpm:8.3.36-arm64-prod-v001:latest .super5:latest --platform linux/arm64 . --load  //保存目标架构镜像
>
> docker buildx build -t php-fpm:8.3.36-arm64-prod-v001:latest .registry/super5:latest --platform linux/arm64,linux/amd64 . --push //多平台镜像编译推送至远程目标仓库
