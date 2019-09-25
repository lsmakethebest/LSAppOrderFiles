# LSAppOrderFiles
基于LLVM二进制重排





## 基于 Clang SanitizerCoverage 的方案

在 [Clang 10 documentation](https://clang.llvm.org/docs/SanitizerCoverage.html#tracing-pcs) 中可以看到 LLVM 官方对 SanitizerCoverage 的详细介绍，包含了示例代码。

简单来说 SanitizerCoverage 是 Clang 内置的一个代码覆盖工具。它把一系列以 `__sanitizer_cov_trace_pc_` 为前缀的函数调用插入到用户定义的函数里，借此实现了全局 AOP 的大杀器。其覆盖之广，包含 Swift/Objective-C/C/C++ 等语言，Method/Function/Block 全支持。

##### 1.开启 SanitizerCoverage 

开启 SanitizerCoverage 的方法是：在 build settings 里的 “Other C Flags” 中添加 `-fsanitize-coverage=func,trace-pc-guard`。如果含有 Swift 代码的话，还需要在 “Other Swift Flags” 中加入 `-sanitize-coverage=func` 和 `-sanitize=undefined`。所有链接到 App 中的二进制都需要开启 SanitizerCoverage，这样才能完全覆盖到所有调用。

##### 2.将AppOrderFiles.m拖到项目里

在认为启动完成的地方发送通知,key随意

`[[NSNotificationCenter defaultCenter]postNotificationName:@"app_launch_finish" object:nil];`

修改AppOrderFiles.m通知定义的key保持一致

`NSString * **const** APP_LAUNCH_FINISH_NOTIFICATION = @"app_launch_finish";`

##### 3.运行一次程序，导出沙盒目录下的order.txt到电脑上

##### 4.配置工程 order file为生成的order.txt

##### 5.关闭SanitizerCoverage，移除AppOrderFiles.m

##### 6.开启link map写入

##### 7.再次运行程序，对比linkmap文件和order.txt是否一致，同时对比优化后的启动时间

参考链接： https://my.oschina.net/u/2345393/blog/3101326>

