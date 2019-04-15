FROM mcr.microsoft.com/windows/servercore as win10sdk

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
ADD http://download.microsoft.com/download/6/3/B/63BADCE0-F2E6-44BD-B2F9-60F5F073038E/standalonesdk/SDKSETUP.EXE C:/sdksetup.exe
RUN $ExpectedSHA='23B87A221804A8DB90BC4AF7F974FD5601969D40936F856942AAC5C9DA295C04'; \
    $ActualSHA=$(Get-FileHash -Path C:\sdksetup.exe -Algorithm SHA256).Hash; \
    If ($ExpectedSHA -ne $ActualSHA) { Throw 'sdksetup.exe hash does not match the expected value!' }

RUN New-Item -Path c:\sdksetup -Type Directory -Force|out-null
RUN $procArgs=@('-norestart','-quiet','-ceip off','-Log c:\sdksetup\sdksetup.exe.log','-Layout c:\sdksetup', \
        '-Features OptionId.NetFxSoftwareDevelopmentKit OptionId.WindowsSoftwareDevelopmentKit'); \
    Write-Host 'Executing download of Win10SDK files (approximately 400mb)...'; \
    $proc=Start-Process -FilePath c:\sdksetup.exe -ArgumentList $procArgs -wait -PassThru ; \
    if ($proc.ExitCode -eq 0) { \
        Write-Host 'Win10SDK download complete.' \
    } else { \
        get-content -Path c:\sdksetup\sdksetup.exe.log -ea Ignore| write-output ; \
        throw ('C:\SdkSetup.exe returned '+$proc.ExitCode) \
    }

RUN 'Windows SDK for Windows Store Apps Tools-x86_en-us.msi' | ForEach-Object -Process { \
        Write-Host ('Executing MsiExec.exe with parameters:'); \
        $MsiArgs=@(('/i '+[char]0x0022+'c:\sdksetup\Installers\'+$_+[char]0x0022), \
            ('/log '+[char]0x0022+'c:\sdksetup\'+$_+'.log'+[char]0x0022),'/qn','/norestart'); \
        Write-Output $MsiArgs; \
        $proc=Start-Process msiexec.exe -ArgumentList $MsiArgs -Wait -PassThru -Verbose; \
        if ($proc.ExitCode -eq 0) { Write-Host '...Success!' \
        } else { \
            get-content -Path ('c:\sdksetup\'+$_+'.log') -ea Ignore | write-output; \
            throw ('...Failure!  '+$_+' returned '+$proc.ExitCode) \
        } \
     };

RUN $win10sdkBinPath = ${env:ProgramFiles(x86)}+'\Windows Kits\10\bin\x64'; \
    if (Test-Path -Path $win10sdkBinPath\mc.exe) { \
      Write-Host 'Win10 SDK 10.1.14393.0 Installation Complete.' ; \
      Remove-Item c:\sdksetup.exe -Force; \
      Remove-Item c:\sdksetup\ -Recurse -Force; \
    } else { Throw 'Installation failed!  See logs under c:\sdksetup\' };


FROM stefanscherer/node-windows

COPY --from=win10sdk ["C:\\\\Program Files (x86)\\\\Windows Kits\\\\10\\\\bin\\\\x64", "C:/kit"]

RUN npm install -g electron-windows-store
CMD cmd
