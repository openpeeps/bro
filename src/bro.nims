switch "threads", "on"
switch "define", "useMalloc"
switch "gc", "arc"
switch "deepcopy", "on"
switch "define", "msgpack_obj_to_map"

when defined release:
  switch "define", "danger"
  switch "opt", "speed"
  switch "passC", "-flto"
  switch "passL", "-flto"
  switch "define", "nimAllocPagesViaMalloc"

when defined napibuild:
  switch "passC", "-I/usr/include/node -I/usr/local/include/node"