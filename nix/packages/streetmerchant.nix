{ lib, writers, npmlock2nix, writeText, python3Packages, sources, puppeteer-cli, chromium }:
let
  notify = writers.writePython3 "gpubot"
    {
      libraries = [ python3Packages.irc ];
      flakeIgnore = [ "E501" ];
    } ''
    import irc.bot
    import irc.connection
    import logging
    import ssl
    import time
    import sys

    logging.basicConfig(level=logging.DEBUG)


    class TestBot(irc.bot.SingleServerIRCBot):
        def __init__(self, channel, nickname, server, url, port=6667):
            self.url = url
            ssl_factory = irc.connection.Factory(wrapper=ssl.wrap_socket)
            irc.bot.SingleServerIRCBot.__init__(self, [(server, port)], nickname, nickname, connect_factory=ssl_factory)
            self.channel = channel

        def on_welcome(self, c, e):
            c.join(self.channel)
            time.sleep(3)
            self.connection.notice(self.channel, "GPU ALERT: " + self.url)
            time.sleep(3)
            sys.exit(0)


    if __name__ == "__main__":
        bot = TestBot("#cda-lan-gpus", "gpubot", "irc.hackint.org", sys.argv[1], 6697)
        bot.start()
  '';
  desktopjs = writeText "desktop.ts" ''
    import {Link, Store} from '../store/model';
    import {Print, logger} from '../logger';
    import {config} from '../config';
    import {join} from 'path';
    import notifier from 'node-notifier';

    const {desktop} = config.notifications;
    const { spawnSync } = require('child_process');

    export function sendDesktopNotification(link: Link, store: Store) {
      spawnSync('${notify}',[link.cartUrl ? link.cartUrl : link.url])
      //if (desktop) {
      //  logger.debug('↗ sending desktop notification');
      //  (async () => {
      //    notifier.notify({
      //      icon: join(
      //        __dirname,
      //        '../../../docs/assets/images/streetmerchant-logo.png'
      //      ),
      //      message: link.cartUrl ? link.cartUrl : link.url,
      //      open: link.cartUrl ? link.cartUrl : link.url,
      //      title: Print.inStock(link, store),
      //    });

      //    logger.info('✔ desktop notification sent');
      //  })();
      //}
    }
  '';
in
npmlock2nix.build {
  src = sources.streetmerchant;
  buildCommands = [ "cp ${desktopjs} src/messaging/desktop.ts" "npm run compile" ];
  installPhase = ''
    cp -r build $out
    mkdir $out/bin
    mkdir $out/lib
    mv node_modules $out/lib/node_modules

    cat - <<EOF > $out/bin/streetmerchant
    #!/usr/bin/env sh
    export NODE_PATH="${placeholder "out"}/src:${placeholder "out"}/lib/node_modules"
    export PATH="${lib.getBin puppeteer-cli}/bin/:${lib.getBin chromium}/bin/:\$PATH"
    export PUPPETEER_EXECUTABLE_PATH="${lib.getBin chromium}/bin/chromium"

    set -ex
    cd ${placeholder "out"}/src
    exec ./run.sh
    EOF
    chmod +x $out/bin/streetmerchant

    cat - <<EOF > $out/src/run.sh
    #!/usr/bin/env node
    require('./index.js')
    EOF
    chmod +x $out/src/run.sh

    patchShebangs $out/bin/*
  '';
  node_modules_attrs = {
    PUPPETEER_SKIP_DOWNLOAD = "123";
  };
}
