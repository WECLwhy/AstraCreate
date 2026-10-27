# 文件格式与常用操作

[文档首页](../README.md) · [English](../en/features.md)

| 格式 | 扩展名 | 初始内容 | 默认 |
|---|---|---|---|
| Word / Excel / PowerPoint | .docx / .xlsx / .pptx | 空白 Office 文档 | 开启 |
| 文本 / Markdown | .txt / .md | 空白 UTF-8 | 开启 |
| JSON | .json | 有效空对象 `{}` | 关闭 |
| JavaScript / TypeScript | .js / .ts | 空白 UTF-8 | 关闭 |
| Vue | .vue | script setup、template、scoped style 最小结构 | 关闭 |
| HTML | .html | UTF-8 页面最小结构 | 关闭 |
| CSS / YAML | .css / .yaml | 空白 UTF-8 | 关闭 |

本版不提供 PDF。七种开发格式在“常用设置 → 开发文件”独立开启；所有开启的文件格式共用子菜单/平铺设置及中英文偏好。重名自动编号，不覆盖已有项目。

![开发格式](../screenshots/developer-files.png)

## 文件操作

- 终端和 VS Code：以当前文件夹为目标，VS Code 功能需要已安装对应应用。
- 剪切：只记录待移动项目，文件暂不移动，也不写入系统剪贴板。
- 粘贴：此时才移动；重名编号，失败项保留重试。同目录项目不重复移动。
- 复制绝对路径：使用系统剪贴板，分享前留意隐私。

菜单会保存打开当时的目录和选中项。没有有效目录或所需选中项时，相应操作会禁用。新建失败请核对目标目录和诊断日志，避免连续重复操作。
