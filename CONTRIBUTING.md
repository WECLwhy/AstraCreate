# 贡献指南 / Contributing

感谢帮助改进 AstraCreate。先搜索已有 Issue，较大功能请先说明目标、使用场景和兼容性影响，再提交小范围 PR。文档修改请同步中英文，并遵守 [行为准则](CODE_OF_CONDUCT.md)。

Search existing issues first. For larger changes, discuss the goal, use case and compatibility impact before a focused PR. Keep Chinese/English docs aligned and follow the [code of conduct](CODE_OF_CONDUCT.md).

## 开发 / Development

Apple Silicon Mac、Xcode Command Line Tools、Python 3：

```zsh
./scripts/build.sh
./scripts/test.sh
python3 scripts/check-project.py
./scripts/package.sh dist
python3 scripts/check-project.py --package-dir dist
```

构建为本地 ad-hoc 签名。CI 不需要 Apple 凭据，不安装 App、不注册扩展、不重启 Finder。不要将真实系统操作加进单元测试；用隔离目录和替身，避免读写用户设置、队列或文件。

Builds are ad-hoc signed. CI needs no Apple credentials, does not install/register the app or restart Finder. Unit tests must use isolated data and system-action stubs, never user preferences, queues or files.

## PR 与验证 / PR and evidence

说明具体问题、改后行为、验证结果与未验证范围。源码/自动化通过不能写成真实 Finder、Office 或全部系统通过。新增格式需要菜单过滤、命令路由、迁移默认值及实际文件生成验证；不得静默改变已有开关或覆盖用户文件。

Describe the concrete problem, resulting behavior, checks and remaining gaps. Source/automated checks are not live Finder/Office or full-platform acceptance. New formats need filtering, routing, migration defaults and actual generation checks; preserve preferences and existing files.

## 文档与 Wiki / Docs and Wiki

编辑 docs 中的对应中英文页面。Wiki 是生成副本，维护者在独立 Wiki checkout 执行 `python3 scripts/sync-wiki.py /path/to/wiki-checkout`，检查差异后提交推送；不要直接维护两套不同正文。截图需来自真实版本，遮盖个人信息并清除身份元数据。

Edit matching Chinese/English docs. Wiki is generated: maintainers run `python3 scripts/sync-wiki.py /path/to/wiki-checkout`, review its diff and commit/push the separate Wiki repository. Do not maintain divergent copies. Screenshots must reflect the actual version and exclude personal data/identity metadata.

## 发布 / Releases

AppInfo.plist 与 ExtensionInfo.plist 同步提升版本/构建号。先完成本地目标系统验收、构建与回归，再生成 PKG、源码 ZIP、SHA256SUMS 和双语说明。核对源文件、包载荷、大小和摘要；草稿附件检查成功后再发布。发布后重新下载校验。每一步失败必须停止，不得在校验失败后继续发布。

Bump host/extension version and build together. Complete target-platform acceptance, build/tests, then produce PKG/source ZIP/SHA256SUMS and bilingual notes. Verify source inputs, payload, sizes and digests before promotion; re-download afterward. Stop on any failed gate. Published tags/assets are not replaced for documentation-only updates.
