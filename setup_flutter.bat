@echo off
echo ========================================
echo Flutter SDK 安装脚本
echo ========================================
echo.
echo 正在添加 Flutter 到系统环境变量...
echo.

REM 设置当前会话的环境变量
set PATH=D:\flutter\bin;%PATH%

echo Flutter 已安装到: D:\flutter
echo.
echo ========================================
echo 请手动配置系统环境变量：
echo ========================================
echo.
echo 1. 按 Win+R，输入: sysdm.cpl
echo 2. 点击 "高级" -> "环境变量"
echo 3. 在 "用户变量" 中找到 "Path"，点击 "编辑"
echo 4. 点击 "新建"，输入: D:\flutter\bin
echo 5. 点击 "确定" 保存所有更改
echo.
echo 配置完成后，重新打开命令行窗口
echo 输入以下命令验证:
echo   flutter --version
echo.
echo ========================================

pause

REM 验证安装
echo.
echo 正在验证 Flutter 安装...
echo.
D:\flutter\bin\flutter.bat --version

echo.
echo ========================================
echo 运行记账 App 项目:
echo ========================================
echo.
echo cd D:\Project\ExpenseTracker
echo flutter pub get
echo flutter run
echo.
