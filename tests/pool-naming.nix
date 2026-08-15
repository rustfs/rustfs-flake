{ pkgs, self }:

let
  lib = pkgs.lib;
  naming = import ../nixos/pool-naming.nix { inherit lib; };

  # Pads to width, but lets a number that outgrew it through unchanged, the way
  # 98…105 at width 2 has to behave.
  pad =
    width: n:
    let
      s = toString n;
    in
    if width == 0 || builtins.stringLength s >= width then s else lib.fixedWidthNumber width n;

  expand =
    rendered:
    let
      m = builtins.match "(.*)[{]([0-9]+)[.][.][.]([0-9]+)[}]" rendered;
      prefix = builtins.elemAt m 0;
      lo = builtins.elemAt m 1;
      hi = builtins.elemAt m 2;
      width = if lib.hasPrefix "0" lo then builtins.stringLength lo else 0;
      show = pad width;
      from = lib.toIntBase10 lo;
    in
    if m == null then
      [ rendered ]
    else
      map (i: "${prefix}${show (from + i)}") (lib.range 0 (lib.toIntBase10 hi - from));

  # Every shape a real pool takes, swept rather than sampled.
  bases = [
    "/mnt/rustfs"
    "node"
    "recorder-a-"
    "192.168.1."
    "2001:db8::"
  ];
  starts = [
    0
    1
    8
    9
    10
    98
  ];
  counts = [
    1
    2
    4
    8
  ];
  widths = [
    0
    2
    3
  ];

  nameList =
    base: start: count: width:
    map (i: "${base}${pad width (start + i)}") (lib.range 0 (count - 1));

  swept = lib.concatMap (
    base:
    lib.concatMap (
      start: lib.concatMap (count: map (width: nameList base start count width) widths) counts
    ) starts
  ) bases;

  # Both predicates together are what the module asserts before rendering.
  nameable = items: naming.rangeable items && naming.consistentlyPadded items;

  # Shapes that must be refused, including both bugs the fuzzing turned up.
  refused = [
    [ ]
    [
      "d1"
      "d3"
    ] # gap
    [
      "d3"
      "d2"
      "d1"
    ] # descending
    [
      "d1"
      "d1"
    ] # duplicate
    [
      "d1"
      "d2"
      "x9"
    ] # prefix breaks
    [
      "a1b"
      "a2b"
    ] # digits not at the end
    [
      "d"
      "d1"
    ] # empty suffix
    [
      "d01"
      "d2"
    ] # mixed padding -- rendered d{01…2} => d01,d02
    [
      "d8"
      "d09"
    ] # mixed padding, other way round
    [
      ""
      ""
    ]
    [
      "d1.5"
      "d2.5"
    ]
  ];

  roundTripFailures = lib.concatMap (
    items:
    let
      got = expand (naming.ellipsisOf items);
    in
    lib.optional (!(nameable items) || got != items) {
      inherit items got;
      rangeable = naming.rangeable items;
      consistentlyPadded = naming.consistentlyPadded items;
    }
  ) swept;

  wronglyAccepted = builtins.filter nameable refused;

  failures = {
    roundTrip = roundTripFailures;
    accepted = wronglyAccepted;
  };
  ok = roundTripFailures == [ ] && wronglyAccepted == [ ];
in
pkgs.runCommand "rustfs-pool-naming-test" { } ''
  ${lib.optionalString (!ok) ''
    echo 'pool naming failures:' >&2
    echo ${lib.escapeShellArg (builtins.toJSON failures)} >&2
    exit 1
  ''}
  echo "checked ${toString (builtins.length swept)} rangeable shapes and ${toString (builtins.length refused)} refusals"
  touch $out
''
