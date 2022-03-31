# haskell-platform.nix

A nix based ghc with all the bateries included.

## Get started

```ShellConsole
# Install the binary cache
$ nix-shell -p cachix --command "cachix use haskell-platform"
# Start the shell
$ nix-shell
```

Include extras with `--arg withGUI true`.
