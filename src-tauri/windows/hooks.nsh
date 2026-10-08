; MithenMusic NSIS installer hooks, included by Tauri's generated installer script.
; Adds: install-time language recorded for the app, file associations + default-app candidate,
; a settings-reset prompt when an older install is found, and a clean uninstall.

!include "LogicLib.nsh"

; Default the finish page's "Create desktop shortcut" checkbox to off.
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

; Explorer thumbnail handler (album art). CLSID must match `CLSID_THUMBNAIL_PROVIDER` in
; crates/thumbnail-provider; the ShellEx GUID below is the standard IThumbnailProvider one.
!define THUMB_CLSID "{6E9B2C1A-5D3F-4A7B-9E21-3C4D5E6F7A80}"
!define THUMB_SHELLEX "{E357FCCD-A995-4576-B01F-234630154E96}"

!macro MithenThumb EXT
  WriteRegStr HKLM "Software\Classes\${EXT}\ShellEx\${THUMB_SHELLEX}" "" "${THUMB_CLSID}"
!macroend

!macro MithenUnthumb EXT
  DeleteRegKey HKLM "Software\Classes\${EXT}\ShellEx\${THUMB_SHELLEX}"
!macroend

; One supported audio extension: register MithenMusic as an "Open with" handler for it and list it
; under the app's Capabilities so Windows Settings > Default apps can offer it.
!macro MithenAssoc EXT
  WriteRegStr HKLM "Software\Classes\${EXT}\OpenWithProgids" "MithenMusic.Audio" ""
  WriteRegStr HKLM "Software\MithenApps\MithenMusic\Capabilities\FileAssociations" "${EXT}" "MithenMusic.Audio"
!macroend

!macro MithenUnassoc EXT
  DeleteRegValue HKLM "Software\Classes\${EXT}\OpenWithProgids" "MithenMusic.Audio"
!macroend

!macro NSIS_HOOK_PREINSTALL
  ; Detect an earlier install (an uninstall entry or leftover data) and offer a full settings reset.
  ; Defaults to Yes; a silent install (/S) applies the default.
  ReadRegStr $1 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MithenMusic" "UninstallString"
  StrCmp $1 "" 0 mit_ask
  ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MithenMusic" "UninstallString"
  StrCmp $1 "" 0 mit_ask
  IfFileExists "$APPDATA\com.mithenapps.mithenmusic\mithenmusic.sqlite" mit_ask mit_done
mit_ask:
  IfSilent mit_reset
  MessageBox MB_YESNO|MB_ICONQUESTION "An existing MithenMusic installation was found.$\r$\n$\r$\nReset all settings, accounts, and history?" IDNO mit_done
mit_reset:
  Delete "$APPDATA\com.mithenapps.mithenmusic\mithenmusic.sqlite"
  Delete "$APPDATA\com.mithenapps.mithenmusic\mithenmusic.sqlite-wal"
  Delete "$APPDATA\com.mithenapps.mithenmusic\mithenmusic.sqlite-shm"
  Delete "$APPDATA\com.mithenapps.mithenmusic\mithenmusic.log"
  Delete "$APPDATA\com.mithenapps.mithenmusic\mithenmusic.log.1"
mit_done:
!macroend

!macro NSIS_HOOK_POSTINSTALL
  ; --- Install-time UI language -----------------------------------------------------------------
  ; Map the language page's selection to the app's locale code and store it for the first run.
  StrCpy $0 "en"
  ${If} $LANGUAGE == ${LANG_SPANISH}
    StrCpy $0 "es"
  ${ElseIf} $LANGUAGE == ${LANG_FRENCH}
    StrCpy $0 "fr"
  ${ElseIf} $LANGUAGE == ${LANG_TURKISH}
    StrCpy $0 "tr"
  ${ElseIf} $LANGUAGE == ${LANG_PORTUGUESEBR}
    StrCpy $0 "pt-BR"
  ${ElseIf} $LANGUAGE == ${LANG_INDONESIAN}
    StrCpy $0 "id"
  ${ElseIf} $LANGUAGE == ${LANG_ROMANIAN}
    StrCpy $0 "ro"
  ${ElseIf} $LANGUAGE == ${LANG_KOREAN}
    StrCpy $0 "ko"
  ${ElseIf} $LANGUAGE == ${LANG_RUSSIAN}
    StrCpy $0 "ru"
  ${ElseIf} $LANGUAGE == ${LANG_UKRAINIAN}
    StrCpy $0 "uk"
  ${ElseIf} $LANGUAGE == ${LANG_TRADCHINESE}
    StrCpy $0 "zh-Hant"
  ${ElseIf} $LANGUAGE == ${LANG_POLISH}
    StrCpy $0 "pl"
  ${ElseIf} $LANGUAGE == ${LANG_GERMAN}
    StrCpy $0 "de"
  ${ElseIf} $LANGUAGE == ${LANG_ITALIAN}
    StrCpy $0 "it"
  ${ElseIf} $LANGUAGE == ${LANG_JAPANESE}
    StrCpy $0 "ja"
  ${EndIf}
  WriteRegStr HKLM "Software\MithenApps\MithenMusic" "Locale" "$0"

  ; --- File associations (double-click opens and plays) -----------------------------------------
  WriteRegStr HKLM "Software\Classes\MithenMusic.Audio" "" "MithenMusic Audio"
  WriteRegStr HKLM "Software\Classes\MithenMusic.Audio" "FriendlyTypeName" "MithenMusic Audio"
  WriteRegStr HKLM "Software\Classes\MithenMusic.Audio\DefaultIcon" "" "$INSTDIR\MithenMusic.exe,0"
  WriteRegStr HKLM "Software\Classes\MithenMusic.Audio\shell\open\command" "" '"$INSTDIR\MithenMusic.exe" "%1"'
  !insertmacro MithenAssoc ".mp3"
  !insertmacro MithenAssoc ".flac"
  !insertmacro MithenAssoc ".m4a"
  !insertmacro MithenAssoc ".m4b"
  !insertmacro MithenAssoc ".aac"
  !insertmacro MithenAssoc ".ogg"
  !insertmacro MithenAssoc ".oga"
  !insertmacro MithenAssoc ".opus"
  !insertmacro MithenAssoc ".wav"
  !insertmacro MithenAssoc ".wma"
  !insertmacro MithenAssoc ".aiff"
  !insertmacro MithenAssoc ".aif"
  !insertmacro MithenAssoc ".ape"
  !insertmacro MithenAssoc ".wv"
  !insertmacro MithenAssoc ".mka"

  ; --- Default-app candidate --------------------------------------------------------------------
  ; Windows blocks silently forcing the default (UserChoice), so this only makes MithenMusic a
  ; listed candidate under Settings > Default apps.
  WriteRegStr HKLM "Software\MithenApps\MithenMusic\Capabilities" "ApplicationName" "MithenMusic"
  WriteRegStr HKLM "Software\MithenApps\MithenMusic\Capabilities" "ApplicationDescription" "Desktop YouTube Music client"
  WriteRegStr HKLM "Software\RegisteredApplications" "MithenMusic" "Software\MithenApps\MithenMusic\Capabilities"

  ; --- Explorer thumbnail handler (album art) ---------------------------------------------------
  WriteRegStr HKLM "Software\Classes\CLSID\${THUMB_CLSID}" "" "MithenMusic Thumbnail Provider"
  WriteRegStr HKLM "Software\Classes\CLSID\${THUMB_CLSID}\InprocServer32" "" "$INSTDIR\mithenmusic-thumbnail.dll"
  WriteRegStr HKLM "Software\Classes\CLSID\${THUMB_CLSID}\InprocServer32" "ThreadingModel" "Apartment"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" "${THUMB_CLSID}" "MithenMusic Thumbnail Provider"
  !insertmacro MithenThumb ".mp3"
  !insertmacro MithenThumb ".flac"
  !insertmacro MithenThumb ".m4a"
  !insertmacro MithenThumb ".m4b"
  !insertmacro MithenThumb ".aac"
  !insertmacro MithenThumb ".ogg"
  !insertmacro MithenThumb ".oga"
  !insertmacro MithenThumb ".opus"
  !insertmacro MithenThumb ".wav"
  !insertmacro MithenThumb ".wma"
  !insertmacro MithenThumb ".aiff"
  !insertmacro MithenThumb ".aif"
  !insertmacro MithenThumb ".ape"
  !insertmacro MithenThumb ".wv"
  !insertmacro MithenThumb ".mka"
!macroend

!macro NSIS_HOOK_PREUNINSTALL
  DeleteRegValue HKLM "Software\RegisteredApplications" "MithenMusic"
  DeleteRegKey HKLM "Software\MithenApps\MithenMusic"
  DeleteRegKey HKLM "Software\MithenApps"
  DeleteRegKey HKLM "Software\Classes\MithenMusic.Audio"
  !insertmacro MithenUnassoc ".mp3"
  !insertmacro MithenUnassoc ".flac"
  !insertmacro MithenUnassoc ".m4a"
  !insertmacro MithenUnassoc ".m4b"
  !insertmacro MithenUnassoc ".aac"
  !insertmacro MithenUnassoc ".ogg"
  !insertmacro MithenUnassoc ".oga"
  !insertmacro MithenUnassoc ".opus"
  !insertmacro MithenUnassoc ".wav"
  !insertmacro MithenUnassoc ".wma"
  !insertmacro MithenUnassoc ".aiff"
  !insertmacro MithenUnassoc ".aif"
  !insertmacro MithenUnassoc ".ape"
  !insertmacro MithenUnassoc ".wv"
  !insertmacro MithenUnassoc ".mka"

  ; Thumbnail handler
  DeleteRegKey HKLM "Software\Classes\CLSID\${THUMB_CLSID}"
  DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" "${THUMB_CLSID}"
  !insertmacro MithenUnthumb ".mp3"
  !insertmacro MithenUnthumb ".flac"
  !insertmacro MithenUnthumb ".m4a"
  !insertmacro MithenUnthumb ".m4b"
  !insertmacro MithenUnthumb ".aac"
  !insertmacro MithenUnthumb ".ogg"
  !insertmacro MithenUnthumb ".oga"
  !insertmacro MithenUnthumb ".opus"
  !insertmacro MithenUnthumb ".wav"
  !insertmacro MithenUnthumb ".wma"
  !insertmacro MithenUnthumb ".aiff"
  !insertmacro MithenUnthumb ".aif"
  !insertmacro MithenUnthumb ".ape"
  !insertmacro MithenUnthumb ".wv"
  !insertmacro MithenUnthumb ".mka"
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  ; Nothing the app wrote under the user profile is left behind: settings DB, caches, covers, logs.
  RMDir /r "$APPDATA\com.mithenapps.mithenmusic"
!macroend
