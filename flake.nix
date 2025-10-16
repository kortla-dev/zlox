# {
#   description = "Flake to setup reproducible dev env";
#
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     zig.url = "github:mitchellh/zig-overlay";
#   };
#
#   outputs = { self, nixpkgs, zig }:
#     let
#       system = "x86_64-linux";
#       pkgs = nixpkgs.legacyPackages.${system};
#     in {
#       devShells.${system}.default = pkgs.mkShell {
#         buildInputs = with pkgs; [ # .
#           zig
#           zls
#           valgrind
#         ];
#       };
#     };
# }

{
  description = "My Zig project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Add the zig-overlay flake
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Use the overlay to get Zig packages
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ zig-overlay.overlays.default ];
        };
      in {
        devShells.default = pkgs.mkShell {
          # Now you can use the zig package from the overlay
          packages = [ # .
            # zig-overlay.packages.${system}.master
            pkgs.zig
            pkgs.zls
            pkgs.lldb
            pkgs.vscode
          ];
        };
      });
}
