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
        required=os.environ.get("SPACESBOT_HOMESERVER") is None,
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

    commands = parser.add_subparsers(dest="command")
    commands.add_parser('join')
    tree_parser = commands.add_parser('tree')
    tree_parser.add_argument('output', type=str, default=None, help='Output file for tree markdown')
    
    return parser


def main():
    args = get_argument_parser().parse_args()
    bot = SpacesBot(args.homeserver, args.user, args.access_token, args.room_id)

    if args.command == "join":
        future = bot.run()
    elif args.command == "tree":
        async def write_output(future) -> None:
            result = await future
            if args.output is None:
                print(result)
            else:
                with open(args.output, "w") as fh:
                    fh.write(result)
            
        future = write_output(bot.tree())
    else:
        raise RuntimeError(f"Unknown command {args.command}")
        
    asyncio.get_event_loop().run_until_complete(future)


if __name__ == "__main__":
    main()
