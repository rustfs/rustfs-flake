# Collapsing a pool's names into the one ellipsis expression RustFS accepts.
# Separate from the module so it can be tested directly.
{ lib }:

lib.fix (finalAttrs: {
  # Longest leading run of characters every string shares.
  commonPrefix =
    strs:
    let
      first = builtins.head strs;
      shortest = lib.foldl' (
        n: s: lib.min n (builtins.stringLength s)
      ) (builtins.stringLength first) strs;
      matchesAt = n: lib.all (s: builtins.substring n 1 s == builtins.substring n 1 first) strs;
      go = n: if n >= shortest || !(matchesAt n) then n else go (n + 1);
    in
    if strs == [ ] then "" else builtins.substring 0 (go 0) first;

  # Names collapse only if they share a prefix and count up without gaps.
  rangeable =
    items:
    let
      suffixes = map (lib.removePrefix (finalAttrs.commonPrefix items)) items;
      numbers = map lib.toIntBase10 suffixes;
    in
    items != [ ]
    && (
      builtins.length items == 1
      || (
        lib.all (s: builtins.match "[0-9]+" s != null) suffixes
        && lib.all (x: x) (lib.imap0 (i: n: n == builtins.head numbers + i) numbers)
      )
    );

  # An ellipsis carries the low bound's width across the range, so "01" … "2" would expand to "01" "02"
  consistentlyPadded =
    items:
    let
      suffixes = map (lib.removePrefix (finalAttrs.commonPrefix items)) items;
      widths = map builtins.stringLength suffixes;
      padded = s: builtins.stringLength s > 1 && lib.hasPrefix "0" s;
    in
    !(lib.any padded suffixes) || lib.all (n: n == builtins.head widths) widths;

  # "/mnt/rustfs0" … "/mnt/rustfs3" -> "/mnt/rustfs{0…3}"
  ellipsisOf =
    items:
    let
      prefix = finalAttrs.commonPrefix items;
      suffixes = map (lib.removePrefix prefix) items;
    in
    if builtins.length items == 1 then
      builtins.head items
    else
      "${prefix}{${builtins.head suffixes}...${lib.last suffixes}}";
})
