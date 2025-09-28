call setenv

@echo off
if "%1" == "clean" (
    rd /s /Q Build
    echo "Clean Success"
    goto :END
)

if "%1" == "" (
SET UEFI_TARGET=RELEASE
) else (
SET UEFI_TARGET=%1
)

if "%2" == "" (
SET PACKAGE_NAME=Merak
) else (
SET PACKAGE_NAME=%2
)

SET PACKAGE_TOOL_PATH=%WORKSPACE%\edk2-non-osi\Platform\CIX\Sky1\PackageTool
SET SAVE_BIOS_PATH=%WORKSPACE%\Bin
SET SAVE_BIOS_NAME=%PACKAGE_NAME%
SET FD_NAME=SKY1_BL33_UEFI.fd
SET PACKAGE_BUILD_PATH=%WORKSPACE%\Build\Package

for %%i in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do call set UEFI_TARGET=%%UEFI_TARGET:%%i=%%i%%
xcopy %PACKAGE_TOOL_PATH%\ %PACKAGE_BUILD_PATH%\ /Y /F /E
xcopy %TOOLCHAIN_PATH%\PackageTool\ %PACKAGE_BUILD_PATH%\ /Y /F /E 
::Get version
CD %WORKSPACE%\edk2-platforms
git log -1 --format="%%%H" >version.txt
SET /p PLATFORM_COMMIT_ID=<version.txt
del /f version.txt
::Get Date
for /f "tokens=1-3 delims=/- " %%1 in ("%date%") do set DATATIME=%%1%%2%%3
cd %WORKSPACE%
SET PLATFORM_COMMIT_ID=%PLATFORM_COMMIT_ID:~0,8%

call build -a AARCH64 -t %TOOLCHAIN% -p Platform\CIX\Sky1\%PACKAGE_NAME%\%PACKAGE_NAME%.dsc ^
-D BOARD_NAME=evb ^
-D COMMIT_HASH=%PLATFORM_COMMIT_ID% ^
-D COMPILE_BUILD_DATE=%DATATIME% ^
-D VARIABLE_TYPE=SPI ^
-D SMP_ENABLE=1 ^
-D STANDARD_MM=TRUE ^
-D ACPI_BOOT_ENABLE=1 ^
-b %UEFI_TARGET% 

if %errorlevel% NEQ 0 goto :FAIL

if exist %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\mem_config (
    cd %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\mem_config
    make -f MakefileWin clean
    make -f MakefileWin
    if %errorlevel% NEQ 0 goto :FAIL

    if not exist %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\mem_config\memory_config.bin (
        goto :FAIL
    )
    copy /Y %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\mem_config\memory_config.bin %PACKAGE_BUILD_PATH%\Firmwares\memory_config.bin
    if %errorlevel% NEQ 0 goto :FAIL
)

if exist %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\pm_config (
    cd %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\pm_config
    make -f MakefileWin clean
    make -f MakefileWin
    if %errorlevel% NEQ 0 goto :FAIL

    if not exist %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\pm_config\csu_pm_config.bin (
        goto :FAIL
    )
    copy /Y %WORKSPACE%\edk2-platforms\Platform\CIX\Sky1\%PACKAGE_NAME%\pm_config\csu_pm_config.bin %PACKAGE_BUILD_PATH%\Firmwares\csu_pm_config.bin
    if %errorlevel% NEQ 0 goto :FAIL
)

copy /Y %WORKSPACE%\Build\%PACKAGE_NAME%\%UEFI_TARGET%_%TOOLCHAIN%\FV\%FD_NAME% %PACKAGE_BUILD_PATH%\Firmwares\%FD_NAME%
if %errorlevel% NEQ 0 goto :FAIL
fsutil file createNew %PACKAGE_BUILD_PATH%\Firmwares/dummy.bin 8192

REM Make PR Image
copy /Y %PACKAGE_TOOL_PATH%\Firmwares\bootloader1.img %PACKAGE_BUILD_PATH%\Firmwares\bootloader1.img
copy /Y %PACKAGE_TOOL_PATH%\Firmwares\bootloader2.img %PACKAGE_BUILD_PATH%\Firmwares\bootloader2.img
copy /Y %PACKAGE_TOOL_PATH%\certs\trusted_key_no.crt %PACKAGE_BUILD_PATH%\certs\trusted_key_no.crt
call :MakeImage %SAVE_BIOS_PATH%\%SAVE_BIOS_NAME%.bin
if %errorlevel% NEQ 0 goto :FAIL
REM Make PR2 Image
copy /Y %PACKAGE_TOOL_PATH%\Firmwares2\bootloader1.img %PACKAGE_BUILD_PATH%\Firmwares\bootloader1.img
copy /Y %PACKAGE_TOOL_PATH%\Firmwares2\bootloader2.img %PACKAGE_BUILD_PATH%\Firmwares\bootloader2.img
copy /Y %PACKAGE_TOOL_PATH%\certs2\trusted_key_no.crt %PACKAGE_BUILD_PATH%\certs\trusted_key_no.crt
call :MakeImage %SAVE_BIOS_PATH%\%SAVE_BIOS_NAME%2.bin
if %errorlevel% NEQ 0 goto :FAIL

:SUCCESS
echo "Build Success"
cd %WORKSPACE%
exit /b 0

:FAIL
echo "Build Failed"
cd %WORKSPACE%
exit /b 255

:MakeImage
cd %PACKAGE_BUILD_PATH%
cert_uefi_create_rsa.exe --key-alg rsa --key-size 3072 --hash-alg sha256 -p --ntfw-nvctr 223 ^
--nt-fw-cert certs\nt_fw_cert.crt ^
--nt-fw-key-cert certs\nt_fw_key.crt ^
--nt-fw-key Keys\oem_privatekey.pem ^
--non-trusted-world-key Keys\oem_privatekey.pem ^
--nt-fw Firmwares\%FD_NAME%

if %errorlevel% NEQ 0 exit /b 255

fiptool.exe create ^
--trusted-key-cert certs\trusted_key_no.crt ^
--nt-fw-key-cert certs\nt_fw_key.crt ^
--nt-fw-cert certs\nt_fw_cert.crt ^
--nt-fw Firmwares\%FD_NAME% ^
Firmwares\bootloader3.img

if %errorlevel% NEQ 0 exit /b 255
cix_package_tool.exe -c %PACKAGE_BUILD_PATH%\spi_flash_config_all.json -o %~1
if %errorlevel% NEQ 0 exit /b 255
cd %WORKSPACE%
exit /b 0