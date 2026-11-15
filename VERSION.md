# 钱迹 QianJi · SemVer 2.0.0

- MAJOR 2：账目删除改为「软删除 + 回收站」，数据语义与导出格式发生变化
  （BackupPayload version 1 → 2，新增 deletedAt 与新设置项；v1 备份仍可导入）
- MINOR 0：新增 Q 弹玻璃胶囊、文字显隐开关、回收站二级页、统一动画层 Motion
- PATCH 0：首个 2.x 正式包

构建标识：QJ-2.0.0
MARKETING_VERSION = 2.0.0 / CURRENT_PROJECT_VERSION = 2

## 本版新增
1. 设置 → 外观与手感：显示底栏文字 / 显示＋页类别文字（关闭后图标放大，底栏高度不变）
2. Q 弹玻璃胶囊（无折射、无扭曲）：底栏选中态、＋页分类选中、收支切换滑块、保存按钮点击跳动
3. 交易列表从右往左滑呼出删除（无长按）；设置可关闭删除二次确认
4. 回收站二级页：恢复 / 单条彻底删除 / 清空；全局保留 3 / 7 / 30 天 / 不自动清理；进前台时检查过期
5. Motion.swift 统一全部弹簧参数，全 app 不再散写魔数
6. 导出/导入按 UUID 去重，可多次导入不产生重复

## 出包
bash scripts/build_unsigned_ipa.sh
