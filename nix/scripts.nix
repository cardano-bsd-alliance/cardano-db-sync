{ pkgs, customConfigs ? [ pkgs.customConfig ] }:
let
  inherit (pkgs) lib cardanoLib;
  inherit (pkgs.commonLib) evalService;
  mkScript = envConfig:
    let
      service = evalService {
        inherit pkgs customConfigs;
        serviceName = "cardano-db-sync";
        modules = [
          ./nixos/cardano-db-sync-service.nix
          {
            services.cardano-db-sync = {
              postgres.user = lib.mkDefault "*";
              environment = lib.mkDefault envConfig;
              cluster = lib.mkDefault envConfig.name;
              dbSyncPkgs = lib.mkDefault pkgs;
            };
          }
        ];
      };
    in lib.recurseIntoAttrs {
      db-sync = pkgs.writeScriptBin "cardano-db-sync-${service.cluster}" ''
        #!${pkgs.runtimeShell}
        set -euo pipefail
        ${service.script} $@
      '' // {
        passthru = { inherit service; };
      };
    };
in cardanoLib.forEnvironments mkScript
