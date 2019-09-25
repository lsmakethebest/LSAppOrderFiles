# LSAppOrderFiles
基于LLVM二进制重排

## 使用
开启 SanitizerCoverage 的方法是：在 build settings 里的 “Other C Flags” 中添加 -fsanitize-coverage=func,trace-pc-guard。如果含有 Swift 代码的话，还需要在 “Other Swift Flags” 中加入 -sanitize-coverage=func 和 -sanitize=undefined。所有链接到 App 中的二进制都需要开启 SanitizerCoverage，这样才能完全覆盖到所有调用。
