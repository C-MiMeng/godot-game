# 资源目录

图片、音频、3D 模型、字体等二进制资源放在这里。

- 常见的二进制扩展名已经由根目录的 `.gitattributes` 交给 Git LFS 管理。
- 提交前用 `git lfs ls-files` 确认资源没有以普通 Git 对象入库。
- 不要放 `.godot/` 导入缓存、导出产物或临时文件。
- 需要独占编辑的源文件（PSD、Blend 等）可以先 `git lfs lock <path>`，完成后解锁。
