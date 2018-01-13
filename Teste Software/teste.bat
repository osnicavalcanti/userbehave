ECHO OFF
if not exist c:\teste\%computername% mkdir c:\teste\%computername%
start BrowsingHistoryView.exe /scomma c:\teste\%computername%\browser.csv
start RecentFilesView.exe /stab c:\teste\%computername%\recent.csv 
##xcopy "c:\teste\%computername%\*.*" "\\altarfs5\GETIF_USO_INTERNO\COTEC\Segurança Tecnológica Riscos e Continuidade em TI\teste" /s/e
