# 贡献指南

简体中文 ｜ [English](CONTRIBUTING.en.md) ｜ [한국어](CONTRIBUTING.ko.md)

欢迎通过 Issue 和 Pull Request 改进 Yahagi。

只想自行打包使用，请先看 [源码构建与验证](BUILDING.md)；修改主题、文字、资源或制作独立版本，请看 [定制指南](CUSTOMIZING.md)。

## 开发流程

1. Fork 仓库并从默认分支创建功能分支。
2. 保持改动聚焦，并为行为变更补充测试。
3. 不要提交账号数据、接口正文、Cookie、令牌、签名密钥或本机配置。
4. 按 [源码构建与验证](BUILDING.md) 配置环境，并在提交前运行其中的检查命令。
5. 在 Pull Request 中说明动机、影响范围、测试结果和需要人工验证的部分。

## 代码与素材

- Dart 代码使用 `dart format` 统一格式。
- 对外日志和错误信息不得包含敏感请求数据。
- 新增第三方依赖或素材时，请同时更新 `THIRD_PARTY_NOTICES`，并确保允许随仓库和应用分发。
- 不要提交 `test/failures/`、构建产物、IDE 配置或签名文件。
