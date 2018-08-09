use HTTP::UserAgent;
use HTTP::Request::Common;
use URI::Encode;
use JSON::Tiny;
use Matrix::Client::Exception;

unit role Matrix::Client::Requester;

has $.home-server is required;
has $.access-token = "";

has $!ua = HTTP::UserAgent.new;
has $!client-endpoint = "/_matrix/client/r0";
has $!url-prefix = "";
has $!sync-since = "";

method !handle-error($response) is hidden-from-backtrace {
    unless $response.is-success {
        my $data = from-json($response.content);
        X::Matrix::Response.new(:code($data<errcode>), :error($data<error>)).throw;
    }
    $response
}

method !access-token-arg {
    $!access-token ?? "access_token=$!access-token" !! ''
}

method get(Str $path, :$media = False, *%data) {
    my $query = "?{self!access-token-arg}";
    for %data.kv -> $k,$v {
        $query ~= "&$k=$v" if $v.so;
    }
    my $encoded-path = $path.subst('#', '%23');
    my $uri = $.base-url(:$media) ~ $encoded-path ~ uri_encode($query);
    return self!handle-error($!ua.get($uri));
}

method base-url(Bool :$media? = False --> Str) {
    if !$media {
        "$.home-server$!client-endpoint$!url-prefix"
    } else {
        "$.home-server/_matrix/media/r0"
    }
}

multi method post(Str $path, Str $json, :$media = False) {
    my $encoded-path = $path.subst('#', '%23');
    my $url = $.base-url(:$media) ~ $encoded-path ~ "?{self!access-token-arg}";
    my $req = HTTP::Request.new(POST => $url,
                                Content-Type => 'application/json');
    $req.add-content($json);
    return self!handle-error($!ua.request($req));
}

multi method post(Str $path, :$media = False, *%params) {
    my $json = to-json(%params);
    $.post($path, $json, :$media)
}

method post-bin(Str $path, Buf $buf, :$content-type) {
    my $encoded-path = $path.subst('#', '%23');
    my $req = POST($.base-url(:media)
            ~ $encoded-path
            ~ "?{self!access-token-arg}",
        content => $buf,
        Content-Type => $content-type
    );
    return self!handle-error($!ua.request($req));
}

multi method put(Str $path, Str $json) {
    my $encoded-path = $path.subst('#', '%23');
    my $req = HTTP::Request.new(PUT => $.base-url() ~ $encoded-path ~ "?{self!access-token-arg}",
                                Content-Type => 'application/json');
    $req.add-content($json);
    return self!handle-error($!ua.request($req))
}

multi method put(Str $path, *%params) {
    self.put($path, to-json(%params))
}
