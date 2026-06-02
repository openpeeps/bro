--mm:atomicArc
--deepcopy:on
--define:nimPreviewHashRef

when defined release:
  --opt:speed
  when defined clang:
    --passC:"-O3 -flto -march=native"
    --passL:"-O3 -flto -march=native"
