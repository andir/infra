$TTL 3600
$ORIGIN darmstadt.io.
@    IN    SOA    ns1.h4ck.space. foo.h4ck.space. (
                2019032301 ; Serial - date by convention
                10800      ; Refresh
                600        ; Retry
                604800     ; Expire
                600        ; Negative cache TTL
)

        IN      NS      ns1.h4ck.space.
        IN      NS      ns2.h4ck.space.
        IN      MX      20 mx.h4ck.space.
        IN      TXT     "v=spf1 mx -all"
        IN      AAAA    2a01:4f8:201:6344::2
        IN      A       148.251.9.69

