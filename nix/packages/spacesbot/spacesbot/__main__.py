import asyncio
import os
import argparse
from . import SpacesBot


def get_argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--homeserver",
        type=str,
        default=os.environ.get("SPACESBOT_HOMESERVER"),
        required=os.environ.get("SPACESBOT_HOMESEREVER") is None,
        help="The base URL of the homeserver. e.g. https://matrix.foobar.tld. (Defaults to the environment variable SPACESBOT_HOMESERVER)",
    )
    parser.add_argument(
        "--user",
        type=str,
        default=os.environ.get("SPACESBOT_USER"),
        required=os.environ.get("SPACESBOT_USER") is None,
        help="The local part of the bots user. e.g. myname when @myname:server.tld is the full matrix id. (Defaults to the environment variable SPACESBOT_USER)",
    )
    parser.add_argument(
        "--access-token",
        type=str,
        default=os.environ.get("SPACESBOT_ACCESS_TOKEN"),
        required=os.environ.get("SPACESBOT_ACCESS_TOKEN") is None,
        help="The access-token for the martrix account. (Defaults to the environment variable SPACESBOT_ACCESS_TOKEN)",
    )
    parser.add_argument(
        "room_id",
        type=str,
        help="The matrix room id of the space to join",
    )

    return parser


def main():
    args = get_argument_parser().parse_args()
    bot = SpacesBot(args.homeserver, args.user, args.access_token, args.room_id)

    future = bot.run()
    asyncio.get_event_loop().run_until_complete(future)


if __name__ == "__main__":
    main()
