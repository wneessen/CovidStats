## Filename:    InfluxDb.pm
## Description: A set of helper method for CovidStats to interact with InfluxDB
## Creator:     Winni Neessen <winni@neessen.net>

package CovidStats::Plugin::InfluxDb;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw(url_escape);
use Carp;
our $VERSION = '0.01';

## Register the plugin // register {{{
sub register {
    my ($self, $app, $conf) = @_;
    
    ## Initialize the helper
    $app->helper(callInflux         => \&_callInflux);
}
# }}}

## Perform the web request to InfluxDB // _callInflux() {{{
##  Requires:       post data
##  Optional:       undef
##  onSuccess:      1
##  onFailure:      undef
sub _callInflux {
    my $self = shift;
    my $postData = shift;
    if(!defined($postData)) {
        $self->app->log->error('No POST data given. Request canceled');
        return undef;
    }

    ## Get all config settings first
    my $userAgent = $self->ua;
    my $influxHost = $self->config->{InfluxDbServer};
    my $influxPort = $self->config->{InfluxDbPort};
    my $influxUser = url_escape $self->config->{influxDbUser};
    my $influxPass = url_escape $self->config->{influxDbPass};
    my $influxDbase = url_escape $self->config->{InfluxDbDatabase};
    my $reqUrl = 'http://' . $influxHost . ':' . $influxPort . '/write?u=' . $influxUser . '&p=' . $influxPass . '&db=' . $influxDbase . '&precision=s';

    ## Start transaction
    my $transAct = $userAgent->build_tx(POST => $reqUrl => $postData); 
    $transAct = $userAgent->start($transAct);
    if(!$transAct->error) {
        return 1;
    }
    else {
        my $txError = $transAct->error;
        $self->app->log->fatal('Unable to write to InfluxDB: ' . $txError->{message});
        if(defined($transAct->result->body)) {
            $self->app->log->fatal('Server returned the following error: ' . $transAct->result->body);
        }
        return undef;
    }
}
# }}}

1;
