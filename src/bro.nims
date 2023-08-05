--threads:on
--define:useMalloc
--mm:arc
--deepcopy:on
--define:msgpack_obj_to_map
--define:httpxServerName:"BroStyleSync"
--define:nimPreviewHashRef

when defined release:
  --opt:speed
  --define:danger
  --checks:off
  --passC:"-flto"
  --passL:"-flto"
  --define:nimAllocPagesViaMalloc
# else:
#   --profiler:on
#   --stacktrace:on

when defined wasm:
  --nimcache:tmp
  --os:linux
  --cpu:wasm32
  --cc:clang
  when defined(windows):
    --clang.exe:emcc.bat
    --clang.linkerexe:emcc.bat
    --clang.cpp.exe:emcc.bat
    --clang.cpp.linkerexe:emcc.bat
  else:
    --clang.exe:emcc
    --clang.linkerexe:emcc
    --clang.cpp.exe:emcc
    --clang.cpp.linkerexe:emcc
  when compileOption("threads"):
    # We can have a pool size to populate and be available on page run
    --passL:"-sPTHREAD_POOL_SIZE=2"
  --listCmd
  --exceptions:goto
  --define:noSignalHandler
  # --objChecks:off # for some reason I get ObjectConversionDefect in std/streams 
  --checks:off
  --define:napiOrWasm
  --passL:"-s ALLOW_MEMORY_GROWTH"
  --passL: "-s INITIAL_MEMORY=512MB"
  --passL: "-o bin/wasm/bro.html --shell-file bin/bro.html"
  --passL: "-s EXPORTED_FUNCTIONS=_free,_malloc,_bro,_main"
  --passL: "-s EXPORTED_RUNTIME_METHODS=ccall,cwrap,setValue,getValue,stringToUTF8,allocateUTF8,UTF8ToString"
elif defined napibuild:
  --define:napiOrWasm
  --define:useMalloc
  --define:danger
  --define:release
  --passC:"-I/usr/include/node -I/usr/local/include/node"
# elif compileOptions("app", "lib"):
  