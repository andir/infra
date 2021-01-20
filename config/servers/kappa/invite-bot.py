import irc.bot
import irc.connection
import subprocess
import logging
import ssl
import re

logging.basicConfig(level=logging.DEBUG)



class TestBot(irc.bot.SingleServerIRCBot):
    def __init__(self, channel, nickname, server, port=6667):
        ssl_factory = irc.connection.Factory(wrapper=ssl.wrap_socket)
        irc.bot.SingleServerIRCBot.__init__(self, [(server, port)], nickname, nickname, connect_factory=ssl_factory)
        self.channel = channel

    def on_welcome(self, c, e):
        c.join(self.channel)

    def on_pubmsg(self, c ,e):
        if e.arguments[0] == '!!invite':
            nick = re.sub('[^a-zA-z0-9]', '_', e.source.nick)
            self.connection.notice(self.channel, "does some magic...")
            output = subprocess.check_output(["machinectl", "shell", "wan-party", "/bin/sh", "-c", f'sudo -u tinc.wan-party tinc.wan-party invite {nick}'])
            for line in output.splitlines():
                self.connection.notice(self.channel, "> " + line.decode())


if __name__ == "__main__":
    bot = TestBot("#cda-lan", "wanpartybot", "irc.hackint.org", 6697)
    bot.start()
