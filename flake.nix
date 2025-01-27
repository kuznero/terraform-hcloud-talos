{
  description = "DevEnv";

  inputs = {
    nixpkgsUnstable.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgsUnstable, flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgsUnstable = import nixpkgsUnstable {
          inherit system;
          config = { allowUnfree = true; };
        };

        ciInputs = with pkgsUnstable; [
          cilium-cli
          kubectl
          kubernetes-helm
          packer
          hcloud
          talosctl
          terraform
        ];

        devInputs = ciInputs ++ (with pkgsUnstable; [ k9s ]);
      in {
        formatter = pkgsUnstable.nixfmt-classic;

        devShells = {
          default = pkgsUnstable.mkShell {
            # ref: https://github.com/go-delve/delve/issues/3085#issuecomment-1419664637
            hardeningDisable = [ "fortify" ];
            buildInputs = devInputs;
            shellHook = ''
              temp_dir=$(mktemp -d)
              cp $HOME/.zshenv $temp_dir/.zshenv || touch $temp_dir/.zshenv
              cp $HOME/.zshrc $temp_dir/.zshrc || touch $temp_dir/.zshrc
              chmod 0644 $temp_dir/.zshenv $temp_dir/.zshrc

              export NIX_FLAKE_NAME="DevEnv"
              export PATH="$(pwd)/scripts:$PATH"

              cat <<'EOF' >> $temp_dir/.zshrc
              export NIX_FLAKE_NAME="DevEnv"
              source <(helm completion zsh)
              source <(kubectl completion zsh)
              source <(talosctl completion zsh)
              EOF

              ZDOTDIR=$temp_dir exec ${pkgsUnstable.zsh}/bin/zsh
            '';
          };
        };
      });
}
