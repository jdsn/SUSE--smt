=head1 NAME

SMT::SCCAPI - Module to use the SCC REST API

=head1 DESCRIPTION

Module to use the SCC REST API

=over 4

=cut

package SMT::SCCAPI;

use strict;
use SMT::Curl;
use SMT::Utils;
use JSON;
use URI;
use Data::Dumper;
use File::Temp qw/ tempfile  /;

=item constructor

  SMT::SCCSync->new(...)

  * url
  * authuser
  * authpass
  * log
  * vblevel
  * useragent

=cut

sub new
{
    my $pkgname = shift;
    my %opt   = @_;
    my $self  = {};

    $self->{VBLEVEL} = 0;
    $self->{LOG}   = undef;
    $self->{USERAGENT}  = undef;
    $self->{URL} = "https://scc.suse.com/connect";
    $self->{AUTHUSER} = "";
    $self->{AUTHPASS} = "";
    $self->{IDENT} = "";

    if(exists $opt{url} && $opt{url})
    {
        $self->{URL} = $opt{url};
    }
    if(exists $opt{vblevel} && defined $opt{vblevel})
    {
        $self->{VBLEVEL} = $opt{vblevel};
    }
    if(exists $opt{authuser} && $opt{authuser})
    {
        $self->{AUTHUSER} = $opt{authuser};
    }
    if(exists $opt{authpass} && $opt{authpass})
    {
        $self->{AUTHPASS} = $opt{authpass};
    }
    if(exists $opt{ident} && $opt{ident})
    {
        $self->{IDENT} = $opt{ident};
    }

    if(exists $opt{log} && defined $opt{log} && $opt{log})
    {
        $self->{LOG} = $opt{log};
    }
    else
    {
        $self->{LOG} = SMT::Utils::openLog();
    }
    if(exists $opt{useragent} && $opt{useragent})
    {
        $self->{USERAGENT} = $opt{useragent};
    }
    else
    {
        $self->{USERAGENT} = SMT::Utils::createUserAgent(log => $self->{LOG}, vblevel => $self->{VBLEVEL});
        $self->{USERAGENT}->protocols_allowed( [ 'https'] );
    }

    bless($self);
    return $self;
}

=item vblevel([level])

Set or get the verbose level.

=cut

sub vblevel
{
    my $self = shift;
    if (@_) { $self->{VBLEVEL} = shift }
    return $self->{VBLEVEL};
}

=item announce([@opts])

Announce a system at SCC.

Options:

  * email
  * reg_code

In case of an error it returns "undef".

=cut

sub announce
{
    my $self = shift;
    my %opts = @_;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "subscriptions/systems");

    my $body = {
        "email" => $opts{email},
        "hostname" => SMT::Utils::getFQDN(),
        "hwinfo" => ""
    };
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO1,
             "Announce data: ".Data::Dumper->dump($body), 0);

    my $headers = {"Authorization" => "Token token=\"".$opts{reg_code}."\""};
    return $self->_request($uri, "post", $headers, $body);
}


=item products

List all products.

Returns json structure containing all products with its repositories.
In case of an error it returns "undef".

Example:

    [
      {
        'release_type' => undef,
        'identifier' => 'SLES',
        'former_identifier' => 'SUSE_SLES',
        'repos' => [
                     {
                       'format' => undef,
                       'name' => 'SLES12-Pool',
                       'distro_target' => 'sle-12-x86_64',
                       'url' => 'https://updates.suse.com/suse/x86_64/update/SLE-SERVER/12-POOL',
                       'id' => 1150,
                       'description' => 'SLES12-Pool for sle-12-x86_64',
                       'tags' => [
                                   'enabled',
                                   'autorefresh'
                                 ]
                     },
                     {
                       'format' => undef,
                       'name' => 'SLES12-Updates',
                       'distro_target' => 'sle-12-x86_64',
                       'url' => 'https://updates.suse.com/suse/x86_64/update/SLE-SERVER/12',
                       'id' => 1151,
                       'description' => 'SLES12-Updates for sle-12-x86_64',
                       'tags' => [
                                   'enabled',
                                   'autorefresh'
                                 ]
                     }
                   ],
        'arch' => 'x86_64',
        'version' => '12',
        'id' => 1117,
        'friendly_name' => 'SUSE Linux Enterprise Server BETA TEST 12 x86_64',
        'product_class' => '7261'
      }
    ]

=cut

sub org_products
{
    my $self = shift;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/products/unscoped");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO1,
             "list products", 0);

    return $self->_request($uri->as_string(), "get", {}, {});
}

=item org_subscriptions

List subscriptions of an organization.

Returns json structure containing subscriptions of an organization with its
system ids consuming it.
In case of an error it returns "undef".

Example:



=cut

sub org_subscriptions
{
    my $self = shift;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/subscriptions");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO1,
             "list organization subscriptions", 0);

    return $self->_request($uri->as_string(), "get", {}, {});
}

=item org_orders

List orders of an organization.

Returns json structure containing orders of an organization with its
order_items pointig to subscriptions.
In case of an error it returns "undef".

Example:



=cut

sub org_orders
{
    my $self = shift;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/orders");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO1,
             "list organization orders", 0);

    return $self->_request($uri->as_string(), "get", {}, {});
}


=item org_repos

List repositories accessible by an organization.

Returns json structure containing repositories accessible by an organization.
In case of an error it returns "undef".

Example:



=cut

sub org_repos
{
    my $self = shift;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/repositories");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO1,
             "list organization repositories", 0);

    return $self->_request($uri->as_string(), "get", {}, {});
}

sub org_systems_list
{
    my $self = shift;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/systems");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO2,
             "list organization systems", 0);

    return $self->_request($uri->as_string(), "get", {}, {});
}

sub org_systems_show
{
    my $self = shift;
    my $id = shift || return undef;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/systems/$id");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO2,
             "show system with id: $id", 0);

    return $self->_request($uri->as_string(), "get", {}, {});
}

sub org_systems_set
{
    my $self = shift;
    my %opts = @_;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "organizations/systems");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO2,
             "forward system with data: ".Data::Dumper->Dump([$opts{body}]), 0);

    return $self->_request($uri, "post", {}, $opts{body});
}

sub org_systems_delete
{
    my $self = shift;
    my $id = shift || return undef;
    my $uri = SMT::Utils::appendPathToURI($self->{URL}, "/organizations/systems/$id");
    if($self->{AUTHUSER} && $self->{AUTHPASS})
    {
        $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_INFO2,
             "delete syste with id: $id", 0);

    return $self->_request($uri->as_string(), "delete", {}, {});
}


sub is_error
{
    my $self = shift;
    my $data = shift;
    return (!defined $data ||
             ref($data) eq "HASH" && exists $data->{type} && $data->{type} eq "error");
}

##########################################################################
### private methods
##########################################################################

# _request($url, $method, {headers}, body)
#
# Issue a REST request to <url> using <method>.
#
# <method> should be one of get, head, post or put
#
# With the hash reference <headers> you can add additionly HTTP headers to
# the request.
#
# With the body reference you can define the body to send.
# The body will be JSON encoded before it is send. The body is
# only added if the method is post or put.
#
# The body could be an error.
sub _request
{
    my $self = shift;
    my $url = shift;
    my $method = shift;
    my $headers = shift;
    my $body = shift;
    my ($fh, $dataTempFile) = tempfile( "smtXXXXXXXX", DIR => "/var/tmp/", UNLINK => 1);

    if ($url !~ /^http/)
    {
        printLog($self->{LOG}, $self->{VBLEVEL}, LOG_ERROR, "Invalid URL: $url");
        return undef;
    }
    my $saveurl = $url;
    $saveurl =~ s/:[^:@]+@/:<secret>@/;
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_DEBUG2, "$method $saveurl");

    $headers = {} if(ref($headers) ne "HASH");
    # generic identification header. Used for debugging in SCC
    $headers->{SMT} = $self->{IDENT};

    my $response = undef;
    if(not exists $headers->{'Accept'})
    {
        # Request API version v3
        $headers->{'Accept'} = 'application/vnd.scc.suse.com.v4+json';
    }
    my $result = undef;
    if ($method eq "get")
    {
        $headers->{':content_file'} = $dataTempFile;
        $response = $self->{USERAGENT}->get($url, %{$headers});
    }
    elsif ($method eq "head")
    {
        $response = $self->{USERAGENT}->head($url, %{$headers});
    }
    elsif ($method eq "post")
    {
        $headers->{'Content-Type'} = 'application/json' if (! exists $headers->{'Content-Type'});
        $response = $self->{USERAGENT}->post($url, %{$headers}, 'content' => JSON::encode_json($body));
    }
    elsif ($method eq "put")
    {
        $headers->{'Content-Type'} = 'application/json' if (! exists $headers->{'Content-Type'});
        $response = $self->{USERAGENT}->put($url, %{$headers}, 'content' => JSON::encode_json($body));
    }
    elsif ($method eq "delete")
    {
        $response = $self->{USERAGENT}->delete($url, %{$headers});
    }
    else
    {
        printLog($self->{LOG}, $self->{VBLEVEL}, LOG_ERROR, "Invalid method");
        return undef;
    }
    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_DEBUG3, Data::Dumper->Dump([$response]));
    if($response->is_success)
    {
        if ($response->content_type() eq "application/json")
        {
            $result = $self->_getDataFromResponse($response, $dataTempFile);
        }
        elsif ($response->code() == 204)
        {
            # Return with No Content
            return {};
        }
        else
        {
            printLog($self->{LOG}, $self->{VBLEVEL}, LOG_ERROR, "Unexpected Content Type");
            return undef;
        }
        # pagination only with GET requests
        if ($method eq "get")
        {
            my ($current, $last) = (1,1);
            while ( $url = $self->_getNextPage($response) )
            {
                ($current, $last) = $self->_getPageNumberInfo($response);
                printLog($self->{LOG}, $self->vblevel(), LOG_INFO2, "Download  (".int(($current/$last*100))."%)\r", 1, 0);
                my $uri = URI->new($url);
                if($self->{AUTHUSER} && $self->{AUTHPASS})
                {
                    $uri->userinfo($self->{AUTHUSER}.":".$self->{AUTHPASS});
                }
                $headers->{':content_file'} = $dataTempFile;
                $response = $self->{USERAGENT}->get($uri->as_string(), %{$headers});
                printLog($self->{LOG}, $self->{VBLEVEL}, LOG_DEBUG3, Data::Dumper->Dump([$response]));
                if (ref($result) eq "ARRAY" && $response->content_type() eq "application/json")
                {
                    push @{$result}, @{$self->_getDataFromResponse($response, $dataTempFile)};
                }
                else
                {
                    printLog($self->{LOG}, $self->{VBLEVEL}, LOG_ERROR, "Unexpected Content Type");
                    return undef;
                }
            }
            printLog($self->{LOG}, $self->vblevel(), LOG_INFO2, "Download  (100%)\n", 1, 0);
        }
    }
    else
    {
        if ($response->content_type() eq "application/json")
        {
            $result = $self->_getDataFromResponse($response, $dataTempFile);
            $result->{type} = "error" if(! exists $result->{type} || $result->{type} ne "error");
        }
        else
        {
            $result = {'type' => 'error', 'error' => $response->status_line,
                       'localized_error' => $response->status_line};
        }
        printLog($self->{LOG}, $self->{VBLEVEL}, LOG_ERROR, "Connection to registration server failed with: ".$response->status_line, 0);
    }
    return $result;
}

sub _getDataFromResponse
{
    my $self = shift;
    my $response = shift;
    my $dataTempFile = shift;

    if($dataTempFile && -s $dataTempFile)
    {
        open( FH, '<', $dataTempFile ) and do
        {
            my $json_text   = <FH>;
            close FH;
            unlink ($dataTempFile);
            return JSON::decode_json($json_text);
        };
    }
    else
    {
        return JSON::decode_json($response->content);
    }

}

sub _getNextPage
{
    my $self = shift;
    my $response = shift;

    return undef if (! $response || ! $response->header("Link"));

    foreach my $link ( split(",", $response->header("Link")) )
    {
        my ($href, $name) = $link =~ /<(.+)>; rel=["'](\w+)["']/igs;
        return $href if($name eq "next");
    }
    return undef;
}

sub _getPageNumberInfo
{
    my $self = shift;
    my $response = shift;
    my ($current, $last) = (1,1);

    return ($current, $last) if (! $response || ! $response->header("Link"));
    foreach my $link ( split(",", $response->header("Link")) )
    {
        my ($pnum, $name) = $link =~ /<.+page=(\d+)>; rel=["'](\w+)["']/igs;
        $last = $pnum if($name eq "last");
        $current = $pnum-1 if($name eq "next");
    }
    return ($current, $last);
}

=back

=head1 AUTHOR

mc@suse.de

=head1 COPYRIGHT

Copyright 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.

=cut

1;

