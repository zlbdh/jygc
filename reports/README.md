# 本地验证报告目录

本目录用于保存本地化拉齐与安全验证产生的报告。

## 目录约定

- `local-validation/`：每次本地基线验证的 Markdown 摘要和 JSON 矩阵

## 文件类型

- `*-summary.md`：给人读的摘要报告
- `*-matrix.json`：给脚本和后续自动化读取的结构化报告
- `*-contracts.md` / `*-contracts.json`：契约发现报告

报告属于运行产物，不作为长期版本资产；仓库只保留目录和说明文件。
