@echo off

set libQtPath=c:\Qt\Qt5.12.9\5.12.9\msvc2017_64

if not exist "%libQtPath%" (
	echo "error: Unable to resolve Qt library. Make sure the 'libQtPath' variable is correct."
	exit 1
	)

rem https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=vs-2019
set vcvarsallCommand=c:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat

if not exist "%vcvarsallCommand%" (
	echo "error: Unable to resolve vcvarsall command file. Make sure the 'vcvarsallCommand' variable is correct."
	exit 1
	)

set upstreamURL=https://github.com/DEAKSoftware/Synergy-Binaries.git

for /F "tokens=* USEBACKQ" %%F in (`git config --get remote.origin.url`) do (
	set queriedURL=%%F
	)

if "%upstreamURL%" NEQ "%queriedURL%" (
	echo "error: Unrecognised Git upstream URL. This script must run within the top-level directory of the Synergy-Binaries repository."
	exit 1
	)

for /F "tokens=* USEBACKQ" %%F in (`git rev-parse --show-toplevel`) do (
	set toplevelPath=%%F
	)

if "%toplevelPath%" EQU "" (
	echo "error: Unrecognised top-level directory. This script must run within the top-level directory of the Synergy-Binaries repository."
	exit 1
	)

set synergyCorePath=%toplevelPath%\Synergy-Core
set buildPath=%synergyCorePath%\build
set binariesPath=%toplevelPath%\Binaries
set toolsPath=%toplevelPath%\Tools

call "%vcvarsallCommand%" x64

:main


call :configure
call :buildStandalone


exit 0

:configureSubmodules

	git submodule update --init --remote --recursive
	exit /b 0

:configureCMake

	cmake -S "%synergyCorePath%" -B "%buildPath%" -G "Visual Studio 16 2019" -D CMAKE_PREFIX_PATH="%libQtPath%" -D CMAKE_BUILD_TYPE=MINSIZEREL -D SYNERGY_ENTERPRISE=ON
	if %errorlevel% equ 1 exit 1
	exit /b 0

:configureVersion

	call "%buildPath%\version.bat"
	set synergyVersion=%SYNERGY_VERSION_MAJOR%.%SYNERGY_VERSION_MINOR%.%SYNERGY_VERSION_PATCH%
	set synergyVersionStage=%SYNERGY_VERSION_STAGE%
	set synergyReleaseName=synergy-%synergyVersion%-%synergyVersionStage%-windows-x64
	exit /b 0

:configure

	call :configureSubmodules
	call :configureCMake
	call :configureVersion
	exit /b 0

:buildMSBuild

	pushd "%buildPath%"

		msbuild synergy-core.sln /p:Platform="x64" /p:Configuration=Release /m
		if %errorlevel% equ 1 exit 1

	popd

	exit /b 0

:buildStandalone

	setlocal

	set releaseBinPath=%buildPath%\bin\Release

	set tempPath=%buildPath%\bin\%synergyReleaseName%

	mkdir "%tempPath%"

	copy "%releaseBinPath%\libEGL.dll"     "%tempPath%"
	copy "%releaseBinPath%\libGLESv2.dll"  "%tempPath%"
	copy "%releaseBinPath%\Qt5Core.dll"    "%tempPath%"
	copy "%releaseBinPath%\Qt5Gui.dll"     "%tempPath%"
	copy "%releaseBinPath%\Qt5Network.dll" "%tempPath%"
	copy "%releaseBinPath%\Qt5Svg.dll"     "%tempPath%"
	copy "%releaseBinPath%\Qt5Widgets.dll" "%tempPath%"
	copy "%releaseBinPath%\synergy.exe"    "%tempPath%"
	copy "%releaseBinPath%\synergyc.exe"   "%tempPath%"
	copy "%releaseBinPath%\synergyd.exe"   "%tempPath%"
	copy "%releaseBinPath%\synergys.exe"   "%tempPath%"
	copy "%releaseBinPath%\syntool.exe"    "%tempPath%"

	mkdir "%tempPath%\Platforms"
	copy "%releaseBinPath%\Platforms" "%tempPath%\Platforms"

	mkdir "%tempPath%\Styles"
	copy "%releaseBinPath%\Styles" "%tempPath%\Styles"

	mkdir "%tempPath%\OpenSSL"
	copy "%synergyCorePath%\ext\openssl\windows\x64\bin\*" "%tempPath%\OpenSSL"
	copy "%synergyCorePath%\ext\openssl\windows\x64\bin\*.dll" "%tempPath%"

	set zipPath=%binariesPath%\%synergyReleaseName%.zip

	powershell.exe -nologo -noprofile -command "& { Compress-Archive -Force -Path '%tempPath%' -DestinationPath '%zipPath%' }"

	endlocal
	exit /b 0

:buildMSI

	pushd "%buildPath%\installer"

		msbuild Synergy.sln /p:Configuration=Release
		if %errorlevel% equ 1 exit 1

	popd

	copy "%buildPath%\installer\bin\Release\Synergy.msi" "%binariesPath%"
	if %errorlevel% equ 1 exit 1

	ren "%binariesPath%\Synergy.msi"	"%synergyReleaseName%.msi"

	exit /b 0

:buildClean

	pushd "%synergyCorePath%"

		git clean -fdx

	popd

	pushd "%toplevelPath%"

		git clean -fdx

	popd

	exit /b 0