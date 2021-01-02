{ pkgs, ... }:
let
  pkg = pkgs.callPackage
    ({ stdenv, cmake, zlib, lua5_1, fetchFromGitHub }:
      stdenv.mkDerivation {
        pname = "pvpgn-server";
        version = "git";

        src = fetchFromGitHub {
          owner = "pvpgn";
          repo = "pvpgn-server";
          rev = "d05a714e3925b603fa6f5aa0b3e2247e92d49656";
          sha256 = "0vlp998zbar3mzh64c0h9a683b5ya2z4kby3f15h2zx2bj4msdv9";
        };

        nativeBuildInputs = [ cmake ];
        buildInputs = [ lua5_1 zlib ];
      })
    { };

  realms = pkgs.writeText "realms.conf" ''
    #################################################################################
    # realm.list  -  List of Diablo II Realms          #
    #-------------------------------------------------------------------------------#
    #                    #
    # Realms are areas that hold closed characters and games.      #
    # Users are given this list of realms to choose from when      #
    # creating a new character.  Next time the character is        #
    # used, they will automatically join the same realm.        #
    #                    #
    # The realm server runs on port 6113 by default.        #
    # If you do not specify a port number, it will use this by default.    #
    #                    #
    # <realmname> : the realm name (mandatory; must start and end with " )    #
    # <description> : the realm description (optional; must start and end with " )  #
    # ip:port - actual ip the d2cs server is running on (mandatory)      #
    #                          #
    # --- realm name ---  --- description ---  --- real address ---    #
    #    (mandatory)      (optional)         (mandatory)    #
    #-------------------------------------------------------------------------------#
    #   "<realmname>"   ["<description>"]        <ip:port>      #
    #                    #
    #################################################################################

    # WARNING!! DO NOT USE "127.0.0.1" or "localhost" FOR ANY IP ADDRESS

    # example (having a d2cs server running on IP 1.2.3.4):
    "D2CS"      "Test"    92.60.37.85:6113
  '';

  config = pkgs.substituteAll {
    src = ./bnetd.conf;
    stateDir = ".";
    configDir = pkg + "/etc";
    outDir = pkg;
    realmConf = realms;
  };

  d2csConfig = pkgs.writeText "d2cs.conf" ''
    realmname    =  D2CS

    servaddrs    =  0.0.0.0:6113
    gameservlist    =  92.60.37.85
    bnetdaddr    =  92.60.37.85:6112

    max_connections = 1000

    # Classic = 0
    # LOD = 1
    # Both = 2 (default)
    lod_realm = 2

    # This sets whether you can convert a clasic char to
    # an expansion char.
    allow_convert = 1

    #default setting is "-_[]"
    account_allowed_symbols = "-_[]"

    #                    #
    #################################################################################

    #################################################################################
    # Message logs                  #
    #-------------------------------------------------------------------------------#
    # Multiple log levels can be defined by connecting them with a comma (,)
    # Available loglevels are:
    #   none
    #   trace
    #   debug
    #   info
    #   warn
    #   error
    #   fatal
    #loglevels = fatal,error,warn,info
    loglevels = fatal,error,warn,info,debug,trace

    #                    #
    #################################################################################

    #################################################################################
    # File and Path section                #
    # Use absolute paths in these lines to avoid problems!        #
    #-------------------------------------------------------------------------------#
    #                    #
    logfile      =  "${LOCALSTATEDIR}/d2cs.log"
    charsavedir    =  "${LOCALSTATEDIR}/charsave"
    charinfodir    =  "${LOCALSTATEDIR}/charinfo"
    bak_charsavedir    =  "${LOCALSTATEDIR}/bak/charsave"
    bak_charinfodir    =  "${LOCALSTATEDIR}/bak/charinfo"
    ladderdir    =  "${LOCALSTATEDIR}/ladders"
    transfile    =  "${SYSCONFDIR}/address_translation.conf"
    d2gsconffile    =  "${SYSCONFDIR}/d2server.ini"
    #pidfile    =  "${LOCALSTATEDIR}/d2cs.pid"

    # d2s template for a new created characters
    newbiefile_amazon    =  "${LOCALSTATEDIR}/files/newbie.save"
    newbiefile_sorceress    =  "${LOCALSTATEDIR}/files/newbie.save"
    newbiefile_necromancer    =  "${LOCALSTATEDIR}/files/newbie.save"
    newbiefile_paladin    =  "${LOCALSTATEDIR}/files/newbie.save"
    newbiefile_barbarian    =  "${LOCALSTATEDIR}/files/newbie.save"
    newbiefile_druid    =  "${LOCALSTATEDIR}/files/newbie.save"
    newbiefile_assasin    =  "${LOCALSTATEDIR}/files/newbie.save"

    #                    #
    #################################################################################

    #################################################################################
    # Misc                    #
    #-------------------------------------------------------------------------------#
    #                    #
    # Message Of The Day
    motd                    =       "No Message Of The Day Set" 

    # Set to non-zero to allow creation of new realm character
    allow_newchar    =  1

    # Do you want d2cs to check client for multilogin for security reason?
    check_multilogin  =  0

    # Maxinum number of character per account
    # Max allowed value is 18 (enforced by server)
    maxchar      =  8

    # Character sorting. Options are: level, ctime, mtime, name, none. (none assumed if
    # not specified).
    #charlist_sort = "none"

    # Do we need ascending or descending order for charlist?
    #charlist_sort_order = "ASC"

    # Maxinum number of games will be shown in join game list
    # Zero = infinite
    maxgamelist    =  20

    # Set to non-zero to allow show all games with difficulty < character difficulty
    # Otherwise, only game with difficulty = character difficulty will be shown
    gamelist_showall  =  0

    # Maxinum time in seconds that a user can idle
    # Zero = infinite
    idletime    =  3600

    # Amount of time to delay shutting down server in seconds.
    shutdown_delay    =  300

    # Amount of time delay period is decremented by either a SIGTERM or SIGINT
    # (control-c) signal in seconds.
    shutdown_decr    =  60
    #
    #################################################################################


    #################################################################################
    # Internal System Settings              #
    # You may just ignore them and use the default value        #
    #-------------------------------------------------------------------------------#
    #
    # How often will the server purge all list to clean unused data (in seconds)
    listpurgeinterval  =  300

    # How often will the server check game queues (in seconds)
    gqcheckinterval    =  60

    # How often will the server retry to connect to bnetd 
    # when connection lost (in seconds)
    s2s_retryinterval  =  10

    # How long time the s2s connection will timeout 
    s2s_timeout    =  10

    # How often the server will check server queues for expired data
    sq_checkinterval  =  300

    # How long time will a server queue data expire
    sq_timeout    =  300

    # Game serer binary files checksum, use zero to skip this checking
    d2gs_checksum    =  0

    # Game server version, use zero to skip this checking
    d2gs_version    =  0

    # Game server password
    d2gs_password    =  ""

    # Maxinum number of second that a game will be shown on list( zero = infinite )
    game_maxlifetime  =  0

    # Maximum level allowed in this (realm) game.
    # Normal games have a max level 99, while the internal field size limit is 255.
    # Extreme game MODs may have higher values, but be warned:
    # !!! Use them at your own risk !!!
    # game_maxlevel       = 255

    # A game will be automatically destroied after how long time idle
    max_game_idletime  =  0

    # Allow Limitation created game with password, player number or level limit?
    allow_gamelimit    =  1

    # Ladder refresh time
    ladder_refresh_interval =  3600

    # server to server connection max idle time in seconds
    s2s_idletime    =  300

    # server to server connection keepalive interval
    s2s_keepalive_interval  =  60

    # all connection timeout check interval
    timeout_checkinterval  =  60

    # game server restart interval
    # when sending SIGUSR2 signal to your d2cs this issues a restart
    # of all connected d2gs after d2gs_restart_delay seconds
    d2gs_restart_delay  =  300

    # ladder start time
    # format: yyyy-mm-dd hh:mm:ss
    # be carefull:
    # all chars created before this date will revert to non-ladder chars
    ladder_start_time  =  ""

    # number of days before a char expires (default 0=unlimited)
    char_expire_day    =  0

    #
    #################################################################################
  '';

  d2csConfig = pkgs.substituteAll {
    src = ./bnetd.conf;
    stateDir = ".";
    configDir = pkg + "/etc";
    outDir = pkg;
    realmConf = realms;
  };

in
{
  systemd.services.pvpgn = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      set -ex
      cd $STATE_DIRECTORY
      mkdir -p users
      mkdir -p clans
      mkdir -p teams
      mkdir -p status
      mkdir -p lua
      mkdir -p reports
      mkdir -p chanlogs
      mkdir -p userlogs
      mkdir -p bnmail

      exec ${pkg}/bin/bnetd -f -c ${config} -D
    '';

    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "pvpgn";
    };
  };

  systemd.services.d2cs = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      set -ex
      cd $STATE_DIRECTORY
      mkdir -p users
      mkdir -p clans
      mkdir -p teams
      mkdir -p status
      mkdir -p lua
      mkdir -p reports
      mkdir -p chanlogs
      mkdir -p userlogs
      mkdir -p bnmail

      exec ${pkg}/bin/d2cs -f -c ${d2csConfig} -D
    '';

    serviceConfig = {
      ExecStart = run;
      DynamicUser = true;
      StateDirectory = "pvpgn";
    };
  };
  networking.firewall.allowedUDPPorts = [ 6112 6113 6200 ];
  networking.firewall.allowedTCPPorts = [ 6112 6113 6200 ];
}
