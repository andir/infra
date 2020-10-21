{ lib ? (import <nixpkgs> { }).lib }:
let
  inherit (import ./lib.nix { inherit lib; }) mesh genPort mod;
in
lib.debug.runTests {


  testModNotBiggerThanM = {
    expr = mod 300 100;
    expected = 0;
  };


  testTwoServers = {
    expr = mesh {
      servers = {
        foo = {
          hostName = "foo.h4ck.space";
        };
        bar = {
          hostName = "bar.h4ck.space";
        };
      };
    };

    expected = {
      foo.connections = [ "bar" ];
      bar.connections = [ "foo" ];
    };
  };

  testWithExtraConnection = {
    expr = mesh {
      servers = {
        foo = {
          hostName = "foo.h4ck.space";
        };
        bar = {
          hostName = "bar.h4ck.space";
        };
        zes = {
          hostName = "zes.h4ck.space";
          connections = [ "bar" ];
        };
      };
    };

    expected = {
      foo.connections = [ "bar" ];
      bar.connections = [ "foo" "zes" ];
      zes.connections = [ "bar" ];
    };
  };
  testWithExtraConnection2 = {
    expr = mesh {
      servers = {
        foo = {
          hostName = "foo.h4ck.space";
          connections = [ ];
        };
        bar = {
          hostName = "bar.h4ck.space";
        };
        zes = {
          hostName = "zes.h4ck.space";
          connections = [ "bar" ];
        };
      };
    };

    expected = {
      foo.connections = [ ];
      bar.connections = [ "zes" ];
      zes.connections = [ "bar" ];
    };
  };

  testGenPort1 = {
    expr = genPort 0 1 "a" "b";
    expected = 0;
  };
  testGenPort2 = {
    expr = genPort 0 100 "foo.bar.baz.very.long.host.name" "b.now";
    expected = 10;
  };
  testGenPort3 = {
    expr = genPort 15000 16000 "foo.bar.baz.very.long.host.name" "b.now";
    expected = 15510;
  };
}
