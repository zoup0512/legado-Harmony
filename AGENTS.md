# AGENTS.md

## Build (HarmonyOS / ArkTS)

hvigor is not on PATH; use DevEco Studio's bundled node + hvigor:

```
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone assembleHap --analyze=normal --parallel --incremental --daemon
```

The build prints ~1000 pre-existing ArkTS warnings (deprecations, "Function may throw exceptions"); only `ERROR` lines matter.

## ArkTS gotchas

- All `import` statements must come before any other statement (`arkts-no-misplaced-imports`).
- `LocalBookAccessLogic.selectLocalCover` must return absolute paths unchanged (covered by `ohosTest/ets/test/LocalBookAccess.test.ets`); use `BookCoverLogic.displaySource` when passing cover paths to `Image`.
- Reading progress / reader settings are stored in preferences keyed by book name (`BookCurrentData_<name>`, `ReaderSetting_<name>`), so book names must stay unique; renames go through `booksUtil.renameBook`.
