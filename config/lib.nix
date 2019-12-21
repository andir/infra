{
  # Inject my custom modules into the machine and set some common things.
  mkMachine = config: {
    imports = [
      config
    ];
  };
}
