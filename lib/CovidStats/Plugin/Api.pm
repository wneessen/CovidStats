## Filename:    Api.pm
## Description: A set of helper method for CovidStats to interact with the CoVID API
## Creator:     Winni Neessen <winni@neessen.net>

package CovidStats::Plugin::Api;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON qw(decode_json);
use Carp;
use Data::Dumper;
our $VERSION = '0.02';

## Register the plugin // register {{{
sub register {
    my ($self, $app, $conf) = @_;
    
    ## Initialize the helper
    $app->helper(fetchState     => \&_fetchState);
    $app->helper(fetchDistrict  => \&_fetchDistrict);
}
# }}}

## Fetch the CoVID-19 state data from the API // _fetchState() {{{
##  Requires:   stateId
##  Optional:   undef
##  onSuccess:  stateHash
##  onFailure:  undef
sub _fetchState {
    my ($self, $stateId) = @_;
    if(!defined($stateId)) {
        $self->app->log->error('Missing parameters. _fetchState required: stateId');
        return undef;
    }

    ## Get all config settings first
    my $userAgent = $self->ua;
    my $apiHost = $self->config->{apiServer};
    my $apiUrl = 'https://' . $apiHost . '/mOBPykOjAyBO2ZKk/arcgis/rest/services/Coronaf%C3%A4lle_in_den_Bundesl%C3%A4ndern/FeatureServer/0/query?f=json&where=OBJECTID_1%3D' . $stateId . '&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=faelle_100000_EW%20desc&resultOffset=0&resultRecordCount=50&cacheHint=true';

    ## Start transaction
    my $transAct = $userAgent->build_tx(GET => $apiUrl);
    $transAct = $userAgent->start($transAct);
    if(!$transAct->error) {
        my $stateHash = decode_json($transAct->result->body);
        return $stateHash;
    }
    else {
        my $txError = $transAct->error;
        $self->app->log->fatal('Unable to fetch CoVID-19 data: ' . $txError->{message});
        return undef;
    }
}
# }}} 

## Fetch the CoVID-19 district data from the API // _fetchDistrict() {{{
##  Requires:   districtId
##  Optional:   undef
##  onSuccess:  districtHash
##  onFailure:  undef
sub _fetchDistrict {
    my ($self, $districtId) = @_;
    if(!defined($districtId)) {
        $self->app->log->error('Missing parameters. _fetchDistrict required: districtId');
        return undef;
    }

    ## Get all config settings first
    my $userAgent = $self->ua;
    my $apiHost = $self->config->{apiServer};
    my $apiUrl = 'https://' . $apiHost . '/mOBPykOjAyBO2ZKk/arcgis/rest/services/Kreisgrenzen_2018_mit_Einwohnerzahl/FeatureServer/0/query?f=json&where=OBJECTID%3D' . $districtId . '&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22Fallzahlen%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true';

    ## Start transaction
    my $transAct = $userAgent->build_tx(GET => $apiUrl);
    $transAct = $userAgent->start($transAct);
    if(!$transAct->error) {
        my $stateHash = decode_json($transAct->result->body);
        return $stateHash;
    }
    else {
        my $txError = $transAct->error;
        $self->app->log->fatal('Unable to fetch CoVID-19 data: ' . $txError->{message});
        return undef;
    }
}
# }}} 

1;