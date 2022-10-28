from nio import AsyncClient, Api, Response, JoinedRoomsError, JoinError, JoinResponse, RoomMessagesResponse, RoomReadMarkersResponse, SyncResponse
from typing import Tuple, List, Dict, Optional, Union
import jinja2

from dataclasses import field, dataclass

import asyncio

class SpacesApi:
    @staticmethod
    def request_spaces(access_token: str, room_id: str, limit=1000, max_depth=1000, next_batch: Optional[str]=None) -> Tuple[str, str]:
        path = ["rooms", room_id, "hierarchy"]
        query = dict(access_token=access_token, limit=limit, max_depth=max_depth)
        if next_batch:
            query['from'] = next_batch
        return "GET", Api._build_path(
            path, query, base_path="/_matrix/client/v1"
        )

@dataclass
class StrippedChildStateEvent:
    content: object = field()
    origin_server_ts: int = field()
    sender: str = field()
    state_key: str = field()
    type: str = field()

    @classmethod
    def from_dict(cls, parsed_dict) -> "StrippedChildStateEvent":
        print(parsed_dict)
        return cls(
            content=parsed_dict["content"],
            origin_server_ts=parsed_dict["origin_server_ts"],
            sender=parsed_dict["sender"],
            state_key=parsed_dict["state_key"],
            type=parsed_dict["type"],
        )

    
@dataclass
class Room:
    # https://spec.matrix.org/v1.4/client-server-api/#get_matrixclientv1roomsroomidhierarchy
    avatar_url: Optional[str] = field()
    canonical_alias: Optional[str] = field()
    children_state: Optional[List[StrippedChildStateEvent]]
    guest_can_join: bool = field()
    join_rule: Optional[str] = field()
    name: str = field()
    num_joined_members: int = field()
    room_id: str = field()
    room_type: Optional[str] = field()
    topic: Optional[str] = field()
    world_readable: bool = field()

    @classmethod
    def from_dict(cls, parsed_dict: Dict) -> "Room":
        children_state = parsed_dict.get("children_state")
        if children_state:
            children_state = list(map(StrippedChildStateEvent.from_dict, children_state))
        return cls(
            avatar_url=parsed_dict.get("avatar_url"),
            canonical_alias=parsed_dict.get("canonical_alias"),
            children_state=children_state,
            guest_can_join=parsed_dict.get("guest_can_join"),
            join_rule=parsed_dict.get("join_rule"),
            name=parsed_dict.get("name"),
            num_joined_members=parsed_dict["num_joined_members"],
            room_id=parsed_dict["room_id"],
            room_type=parsed_dict.get("room_type"),
            topic=parsed_dict.get("topic"),
            world_readable=parsed_dict["world_readable"]
        )


@dataclass
class ChildRoomsChunk(Response):
    rooms: List[Room] = field()
    next_batch: Optional[str] = field()

    @classmethod
    def from_dict(cls, parsed_dict: Dict) -> "ChildRoomsChunk":
        print(parsed_dict)
        return cls(
            rooms=[Room.from_dict(room) for room in parsed_dict["rooms"]],
            next_batch=parsed_dict.get("next_batch"),
        )


class SpacesBot:

    client: AsyncClient

    def __init__(self, homeserver_url: str, user: str, access_token: str, room_id):
        self.client = AsyncClient(homeserver_url)
        self.client.access_token = access_token
        self.client.user_id = user
        self.space_room_id = room_id

    async def _on_connect(self) -> None:
        await self.client.set_displayname("spacesbot - keeps a log of public NixOS channels")
        await self.client.set_presence("unavailable", "I am just a bot")

    async def run(self) -> None:
        await self._on_connect()

        sync_response = await self.client.sync(timeout=30)
        await self.mark_as_read(sync_response)
        await self.join_space(self.space_room_id)

    async def tree(self) -> str:
        await self._on_connect()
        
        rooms = {}
        next_batch = None
        while True:
            response = await self.query_spaces(self.space_room_id, next_batch=next_batch)
            next_batch = response.next_batch
            rooms.update({ room.room_id: room for room in response.rooms })
            print(rooms.keys())
            
            if not next_batch:
                break

        nodes = []
        def walk_node(node, parent, indent=0) -> None:
             prefix = (indent * ' ') + "*"
             this = {'room': node, 'children': []}
             parent.append(this)
             for child in node.children_state:
                 if child.type == 'm.space.child':
                     if child.state_key in rooms:
                         # print(child.content)
                         walk_node(rooms[child.state_key], this['children'], indent=indent+1)
             this['children'] = sorted(this['children'], key=lambda entry: entry['room'].name)
             # move spaces to the end
             spaces = [ r for r in this['children'] if r['room'].room_type == 'm.space' ]
             space_rooms = [ r for r in this['children'] if r['room'].room_type != 'm.space' ]
             this['children'] = space_rooms + spaces
             
        walk_node(rooms[self.space_room_id], nodes)
        env = jinja2.Environment(loader=jinja2.PackageLoader("spacesbot", "templates"))
        template = env.get_template('list.md.j2')
        return template.render(root_node=nodes[0])
        

    async def join_space(self, space_room_id: str):
        joined_rooms = await self.client.joined_rooms()

        if isinstance(joined_rooms, JoinedRoomsError):
            print(joined_rooms)
            raise joined_rooms

        if space_room_id not in joined_rooms.rooms:
            await self.join_via(self.space_room_id)
            joined_rooms = await self.client.joined_rooms()

        additional_spaces = True
        while additional_spaces:
            additional_spaces = False
            response = await self.query_spaces(space_room_id)
            joined_rooms = await self.client.joined_rooms()
            for room in response.rooms:
                if room.room_id in joined_rooms.rooms:
                    continue
                if room.room_type == 'm.space':
                    await self.client.join_via(room.room_id)
                    await self.join_space(room.room_id)

                    additional_spaces = True
                    await asyncio.sleep(5)

        response = await self.query_spaces(space_room_id)
        joined_rooms = await self.client.joined_rooms()
        print("spaces rooms", response.rooms)
        for room in response.rooms:
            if room.room_id not in joined_rooms.rooms:
                print("joining", room.room_id, room)
                response = await self.join_via(room.room_id)
                print(response)
                await asyncio.sleep(5)

        # Do not log this user out as otherwise the access token is invalid
        # await self.client.logout()


    async def query_spaces(self, room_id: str, next_batch: Optional[str]=None) -> ChildRoomsChunk:
        method, path = SpacesApi.request_spaces(self.client.access_token, room_id, next_batch=next_batch)
        print(method, path)
        return await self.client._send(ChildRoomsChunk, method, path)

    async def mark_as_read(self, sync_response: SyncResponse) -> None:
        print("Marking all new events as read")
        joined_rooms = sync_response.rooms.join
        for room_id, room in joined_rooms.items():
            print(f"room: {room_id}")
            events = room.timeline.events
            for event in events:
                print(f"event: {event}")
                response = await self.client.room_read_markers(room_id, fully_read_event=event.event_id, read_event=event.event_id)
                # print(response)

    async def join_via(self, room_id: str) -> Union[JoinResponse, JoinError]:
        via = room_id.split(':')[1]
        print(f"joining {room_id} via {via}")

        path = Api._build_path(['join', room_id], dict(access_token=self.client.access_token, server_name=via))
        response = await self.client._send(JoinResponse, 'POST', path, Api.to_json({}))
        print("join via response: ", response)
        return response
