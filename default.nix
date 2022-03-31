{ withHoogle ? true, withGUI ? false }:
let
  # pin the upstream nixpkgs
  nixpkgsPath = fetchTarball {
    url =
      "https://github.com/NixOS/nixpkgs/archive/4d60081494259c0785f7e228518fee74e0792c1b.tar.gz";
    sha256 = "sha256:15vxvzy9sxsnnxn53w2n44vklv7irzxvqv8xj9dn78z9zwl17jhq";
  };
  nixpkgsSrc = (import nixpkgsPath);

  compilerVersion = "8107";
  compiler = "ghc" + compilerVersion;

  # Helper function to create morphuse-graphql packages
  mk-morpheus-lib = hpPrev: name:
    (let
      src = pkgs.fetchFromGitHub {
        owner = "morpheusgraphql";
        repo = "morpheus-graphql";
        rev = "0.19.0";
        sha256 = "sha256-YY4TDvkFuPxeAPSJurklYzEn3rO6feToiKR4Ii0iLQc=";
      };
    in (hpPrev.callCabal2nix "morpheus-graphql-${name}"
      "${src}/morpheus-graphql-${name}" { }));

  overlays = [
    (final: prev: {
      myHaskellPackages = prev.haskell.packages.${compiler}.override {
        overrides = hpFinal: hpPrev: {
          # Hackage version does not build without a bump
          text-time = (pkgs.haskell.lib.overrideCabal hpPrev.text-time {
            broken = false;
            src = builtins.fetchGit {
              url = "https://github.com/klangner/text-time.git";
              ref = "master";
              rev = "1ff65c2c8845e3fdd99900054f0596818a95c316";
            };
          });

          json-syntax = pkgs.haskell.lib.dontCheck
            (pkgs.haskell.lib.overrideCabal hpPrev.json-syntax {
              broken = false;
            });

          bloodhound = pkgs.haskell.lib.overrideCabal hpPrev.bloodhound {
            version = "0.19.0.0";
            sha256 = "sha256-36ix/I1IEFGA3WlYL996Gi2z/FUNi+7v0NzObnI7awI=";
            broken = false;
          };

          bugzilla-redhat =
            pkgs.haskell.lib.overrideCabal hpPrev.bugzilla-redhat {
              version = "1.0.0";
              sha256 = "sha256-nUITDj5l7e/d4sEyfSpok1Isoy1AIeIad+Fp4QeQJb0=";
              broken = false;
            };

          morpheus-graphql-tests = mk-morpheus-lib hpPrev "tests";
          morpheus-graphql-core = mk-morpheus-lib hpPrev "core";
          morpheus-graphql-code-gen = mk-morpheus-lib hpPrev "code-gen";
          morpheus-graphql-client = mk-morpheus-lib hpPrev "client";

          gerrit = let
            src = builtins.fetchGit {
              url =
                "https://softwarefactory-project.io/r/software-factory/gerrit-haskell";
              ref = "master";
              rev = "7ba07ed5c9da867bd566d114eb2962d7f4b90cf5";
            };
          in pkgs.haskell.lib.dontCheck (hpPrev.callCabal2nix "gerrit" src { });

          # Relude needs a patch to build with hashable-1.4
          relude = hpPrev.relude_1_0_0_1.overrideAttrs (_: {
            patches = [
              (pkgs.fetchpatch {
                url =
                  "https://patch-diff.githubusercontent.com/raw/kowainik/relude/pull/399.patch";
                sha256 = "sha256-dQpJ2v2ohWoc+37GM18fss/Bza9RNZZZNfl4GjSdHv8=";
              })
            ];
          });

          fakedata = hpPrev.fakedata_1_0_2;

          # Bump aeson
          aeson = hpPrev.aeson_2_0_3_0;
          hashable = hpPrev.hashable_1_4_0_2;
          hashable-time = hpPrev.hashable-time_0_3;
          hashtables = hpPrev.hashtables_1_3;
          OneTuple = hpPrev.OneTuple_0_3_1;
          time-compat = hpPrev.time-compat_1_9_6_1;
          text-short = hpPrev.text-short_0_1_5;
          quickcheck-instances = hpPrev.quickcheck-instances_0_3_27;
          semialign = hpPrev.semialign_1_2_0_1;
          attoparsec = hpPrev.attoparsec_0_14_4;
          http2 = hpPrev.http2_3_0_3;
          servant = hpPrev.servant_0_19;
          servant-server = hpPrev.servant-server_0_19;
          dhall = hpPrev.dhall_1_40_2;
          dhall-json = hpPrev.dhall-json_1_7_9;
          dhall-yaml = hpPrev.dhall-yaml_1_2_9;
          swagger2 = hpPrev.swagger2_2_8_2;
          linear = hpPrev.linear_1_21_8;
        };
      };
    })
  ];

  pkgs = nixpkgsSrc {
    inherit overlays;
    system = "x86_64-linux";
  };

  mkGhc = hpkgs:
    if withHoogle then hpkgs.ghcWithHoogle else hpkgs.ghcWithPackages;

  ghc = (mkGhc pkgs.myHaskellPackages) (p:
    with p;
    [ io-streams witch lens relude dhall dhall-json hashtables ]
    ++ (if withGUI then [ sdl2 GLFW-b ] else [ ]));

  hls = pkgs.haskell-language-server.override {
    supportedGhcVersions = [ compilerVersion ];
  };

in pkgs.mkShell { buildInputs = [ pkgs.cabal-install ghc hls ]; }
