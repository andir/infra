let
  mkStation = name: url: {
    ${name} = {
      sequence = [
        {
          service = "media_player.turn_on";
          data = { };
          target.entity_id = "media_player.denon";
        }
        {
          service = "media_player.select_source";
          data.source = "GAME2";
          target.entity_id = "media_player.denon";
        }
        {
          service = "media_player.play_media";
          target.entity_id = "media_player.crappy";
          data = {
            media_content_id = url;
            enqueue = "play";
            media_content_type = "music";
          };
        }
      ];
    };
  };
in
{
  services.home-assistant.config.script =
    (mkStation "play_dlf" "https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3?aggregator=web") //
    (mkStation "play_hr3" "https://dispatcher.rndfnk.com/hr/hr3/live/mp3/high") //
    (mkStation "play_swr3" "https://liveradio.swr.de/sw331ch/swr3/play.aac")
  ;
}
